#!/usr/bin/env python3
"""Spot VM job runner — stateful, preemption-safe heavy job executor.

Runs on a preemptible GCE instance. All state is persisted to GCS so
jobs can resume after preemption without re-doing completed work.

Job state machine (persisted in GCS):
    QUEUED → DOWNLOADING → RUNNING → UPLOADING → COMPLETED
                                                → FAILED

On preemption/restart:
    - Check GCS for incomplete jobs (state != COMPLETED/FAILED)
    - Resume from last checkpoint (e.g., skip download if inputs exist)
    - Re-nack Pub/Sub message so it's redelivered

Handles:
- OpenSCAD rendering (xvfb-run openscad)
- STL analysis (trimesh)
- Blender pro rendering (headless Cycles)
- Pipeline batch audits
"""

import json
import logging
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import pubsub_v1, storage

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("job_runner")

# ─── Config ──────────────────────────────────────────────────────────

GCP_PROJECT = os.environ.get("GCP_PROJECT", "")
ARTIFACTS_BUCKET = os.environ.get("GCS_ARTIFACTS_BUCKET", "")
SUBSCRIPTION = os.environ.get("HEAVY_JOBS_SUB", "")
RESULTS_TOPIC = os.environ.get("JOB_RESULTS_TOPIC", "")

IDLE_TIMEOUT = 300  # 5 min idle → self-terminate
WORK_DIR = Path("/tmp/jobs")
STATE_PREFIX = "job_states"  # GCS prefix for state files

# Job states
QUEUED = "QUEUED"
DOWNLOADING = "DOWNLOADING"
RUNNING = "RUNNING"
UPLOADING = "UPLOADING"
COMPLETED = "COMPLETED"
FAILED = "FAILED"
TERMINAL_STATES = {COMPLETED, FAILED}


def _get_metadata(key: str) -> str:
    import urllib.request
    url = f"http://metadata.google.internal/computeMetadata/v1/instance/attributes/{key}"
    req = urllib.request.Request(url, headers={"Metadata-Flavor": "Google"})
    try:
        return urllib.request.urlopen(req, timeout=2).read().decode()
    except Exception:
        return ""


if not GCP_PROJECT:
    GCP_PROJECT = _get_metadata("gcp-project")
if not ARTIFACTS_BUCKET:
    ARTIFACTS_BUCKET = _get_metadata("artifacts-bucket")
if not SUBSCRIPTION:
    SUBSCRIPTION = _get_metadata("heavy-jobs-sub")
if not RESULTS_TOPIC:
    RESULTS_TOPIC = _get_metadata("job-results-topic")


# ─── Job State Persistence (GCS) ────────────────────────────────────

def _state_key(job_id: str) -> str:
    return f"{STATE_PREFIX}/{job_id}.json"


def load_state(gcs_client, job_id: str) -> dict | None:
    """Load job state from GCS. Returns None if not found."""
    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    blob = bucket.blob(_state_key(job_id))
    if blob.exists():
        return json.loads(blob.download_as_text())
    return None


def save_state(gcs_client, job_id: str, state: dict) -> None:
    """Persist job state to GCS (atomic checkpoint)."""
    state["updated_at"] = datetime.now(timezone.utc).isoformat()
    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    blob = bucket.blob(_state_key(job_id))
    blob.upload_from_string(json.dumps(state, indent=2), content_type="application/json")
    logger.info(f"[STATE] {job_id}: {state.get('status')} (step={state.get('step', '?')})")


def transition(gcs_client, job_id: str, state: dict, new_status: str, **extra) -> dict:
    """Update state and persist. Returns updated state dict."""
    state["status"] = new_status
    state.update(extra)
    save_state(gcs_client, job_id, state)
    return state


# ─── Resume Logic ────────────────────────────────────────────────────

def find_incomplete_jobs(gcs_client) -> list[dict]:
    """Scan GCS for jobs that were interrupted (not COMPLETED/FAILED)."""
    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    incomplete = []
    for blob in bucket.list_blobs(prefix=f"{STATE_PREFIX}/"):
        if blob.name.endswith(".json"):
            state = json.loads(blob.download_as_text())
            if state.get("status") not in TERMINAL_STATES:
                incomplete.append(state)
                logger.info(f"[RESUME] Found incomplete job: {state.get('job_id')} (status={state.get('status')})")
    return incomplete


# ─── Job Steps ───────────────────────────────────────────────────────

def download_inputs(gcs_client, job_id: str, state: dict) -> Path:
    """Download input files from GCS. Skips if already downloaded."""
    job_dir = WORK_DIR / job_id
    input_dir = job_dir / "input"

    # Skip if inputs already exist (resume after preemption during RUNNING)
    if input_dir.exists() and any(input_dir.iterdir()):
        logger.info(f"[DOWNLOAD] Inputs already exist for {job_id}, skipping")
        return job_dir

    input_dir.mkdir(parents=True, exist_ok=True)
    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    input_prefix = state.get("input_prefix", f"jobs/{job_id}/input/")

    for blob in bucket.list_blobs(prefix=input_prefix):
        if blob.name.endswith("/"):
            continue
        local_path = input_dir / Path(blob.name).name
        blob.download_to_filename(str(local_path))
        logger.info(f"  {blob.name} → {local_path.name}")

    return job_dir


def upload_outputs(gcs_client, job_id: str, job_dir: Path) -> list[str]:
    """Upload output files to GCS."""
    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    output_dir = job_dir / "output"
    uploaded = []

    if not output_dir.exists():
        return uploaded

    for file_path in output_dir.rglob("*"):
        if file_path.is_file():
            key = f"jobs/{job_id}/output/{file_path.relative_to(output_dir)}"
            blob = bucket.blob(key)
            blob.upload_from_filename(str(file_path))
            uploaded.append(f"gs://{ARTIFACTS_BUCKET}/{key}")

    return uploaded


def execute_job(job_dir: Path, state: dict) -> dict:
    """Execute the actual work. Returns result dict."""
    job_type = state.get("type", "openscad")
    params = state.get("params", {})
    output_dir = job_dir / "output"
    output_dir.mkdir(exist_ok=True)

    if job_type == "openscad":
        return _exec_openscad(job_dir, params)
    elif job_type == "blender":
        return _exec_blender(job_dir, params)
    elif job_type == "multi_render":
        return _exec_multi_render(job_dir, params)
    else:
        return {"success": False, "error": f"Unknown job type: {job_type}"}


def _exec_openscad(job_dir: Path, params: dict) -> dict:
    scad_file = job_dir / "input" / params.get("scad_file", "main.scad")
    output_dir = job_dir / "output"
    fmt = params.get("format", "stl")
    output_file = output_dir / f"output.{fmt}"

    # Skip if output already exists (resume after preemption during UPLOADING)
    if output_file.exists():
        logger.info(f"Output already exists: {output_file}")
        return {"success": True, "output_file": str(output_file), "resumed": True}

    cmd = ["xvfb-run", "openscad", "-o", str(output_file)]
    for var, val in params.get("variables", {}).items():
        cmd.extend(["-D", f"{var}={val}"])
    cmd.append(str(scad_file))

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    return {
        "success": result.returncode == 0,
        "stdout": result.stdout[:1000],
        "stderr": result.stderr[:1000],
        "output_file": str(output_file) if output_file.exists() else None,
    }


def _exec_blender(job_dir: Path, params: dict) -> dict:
    output_dir = job_dir / "output"
    preset = params.get("preset", "hero")
    script = params.get("script", "/app/system/render_pro.py")

    cmd = [
        "blender", "-b", "-P", script, "--",
        "--stl-dir", str(job_dir / "input"),
        "--output-dir", str(output_dir),
        "--preset", preset,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    return {"success": result.returncode == 0}


def _exec_multi_render(job_dir: Path, params: dict) -> dict:
    """Render multiple SCAD files. Checkpoints after each file."""
    scad_files = params.get("scad_files", [])
    output_dir = job_dir / "output"
    output_dir.mkdir(exist_ok=True)
    results = []

    for scad_name in scad_files:
        output_file = output_dir / f"{Path(scad_name).stem}.stl"
        if output_file.exists():
            logger.info(f"  Skipping (already rendered): {scad_name}")
            results.append({"file": scad_name, "success": True, "resumed": True})
            continue

        scad_path = job_dir / "input" / scad_name
        if not scad_path.exists():
            results.append({"file": scad_name, "success": False, "error": "not found"})
            continue

        cmd = ["xvfb-run", "openscad", "-o", str(output_file), str(scad_path)]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        results.append({"file": scad_name, "success": r.returncode == 0})

    return {
        "success": all(r["success"] for r in results),
        "renders": results,
    }


# ─── Pub/Sub ─────────────────────────────────────────────────────────

def pull_job(subscriber, subscription_path: str) -> dict | None:
    response = subscriber.pull(
        request={"subscription": subscription_path, "max_messages": 1},
        timeout=30,
    )
    if not response.received_messages:
        return None
    msg = response.received_messages[0]
    data = json.loads(msg.message.data.decode())
    data["_ack_id"] = msg.ack_id
    return data


def ack_job(subscriber, subscription_path: str, ack_id: str):
    subscriber.acknowledge(request={"subscription": subscription_path, "ack_ids": [ack_id]})


def publish_result(publisher, topic: str, job_id: str, result: dict):
    message = json.dumps({
        "job_id": job_id,
        "status": "completed" if result.get("success") else "failed",
        "result": result,
        "timestamp": time.time(),
    }).encode()
    future = publisher.publish(topic, message)
    future.result(timeout=10)


# ─── Process a Single Job (stateful) ────────────────────────────────

def process_job(gcs_client, publisher, state: dict) -> dict:
    """Execute a job through its state machine. Resumable after preemption."""
    job_id = state["job_id"]
    status = state.get("status", QUEUED)

    # State machine: resume from wherever we left off
    if status in (QUEUED, DOWNLOADING):
        state = transition(gcs_client, job_id, state, DOWNLOADING)
        job_dir = download_inputs(gcs_client, job_id, state)
        state = transition(gcs_client, job_id, state, RUNNING)
    elif status == RUNNING:
        job_dir = WORK_DIR / job_id
        if not (job_dir / "input").exists():
            # Inputs lost (VM was recreated) — re-download
            state = transition(gcs_client, job_id, state, DOWNLOADING)
            job_dir = download_inputs(gcs_client, job_id, state)
            state = transition(gcs_client, job_id, state, RUNNING)
    elif status == UPLOADING:
        job_dir = WORK_DIR / job_id
    else:
        return state

    # Execute (only if still in RUNNING state)
    if state["status"] == RUNNING:
        result = execute_job(job_dir, state)
        state["result"] = result

        if result.get("success"):
            state = transition(gcs_client, job_id, state, UPLOADING)
        else:
            state = transition(gcs_client, job_id, state, FAILED, result=result)
            if RESULTS_TOPIC:
                publish_result(publisher, RESULTS_TOPIC, job_id, result)
            return state

    # Upload outputs
    if state["status"] == UPLOADING:
        job_dir = WORK_DIR / job_id
        uploaded = upload_outputs(gcs_client, job_id, job_dir)
        state["output_files"] = uploaded
        state = transition(gcs_client, job_id, state, COMPLETED)

        if RESULTS_TOPIC:
            publish_result(publisher, RESULTS_TOPIC, job_id, state.get("result", {}))

    return state


# ─── Graceful Shutdown on SIGTERM (preemption signal) ────────────────

_shutdown = False


def _handle_sigterm(signum, frame):
    global _shutdown
    logger.warning("[SIGTERM] Preemption detected — completing current step then exiting")
    _shutdown = True


signal.signal(signal.SIGTERM, _handle_sigterm)


# ─── Main Loop ───────────────────────────────────────────────────────

def main():
    logger.info("=== Heavy Job Runner Starting ===")
    logger.info(f"Project: {GCP_PROJECT}, Bucket: {ARTIFACTS_BUCKET}")

    WORK_DIR.mkdir(parents=True, exist_ok=True)

    subscriber = pubsub_v1.SubscriberClient()
    publisher = pubsub_v1.PublisherClient()
    gcs_client = storage.Client(project=GCP_PROJECT)

    # Phase 1: Resume incomplete jobs from previous run
    incomplete = find_incomplete_jobs(gcs_client)
    for state in incomplete:
        if _shutdown:
            break
        logger.info(f"[RESUME] Resuming {state['job_id']} from {state['status']}")
        process_job(gcs_client, publisher, state)

    # Phase 2: Pull new jobs from Pub/Sub
    last_job_time = time.time()

    while not _shutdown:
        try:
            job = pull_job(subscriber, SUBSCRIPTION)

            if job is None:
                idle = time.time() - last_job_time
                if idle > IDLE_TIMEOUT:
                    logger.info(f"Idle for {idle:.0f}s, shutting down")
                    break
                time.sleep(10)
                continue

            last_job_time = time.time()
            job_id = job.get("job_id", "unknown")
            ack_id = job.pop("_ack_id", None)

            # Initialize state
            state = load_state(gcs_client, job_id)
            if state and state.get("status") in TERMINAL_STATES:
                logger.info(f"Job {job_id} already {state['status']}, skipping")
                if ack_id:
                    ack_job(subscriber, SUBSCRIPTION, ack_id)
                continue

            if not state:
                state = {
                    "job_id": job_id,
                    "type": job.get("type", "openscad"),
                    "params": job.get("params", {}),
                    "input_prefix": job.get("input_prefix", f"jobs/{job_id}/input/"),
                    "status": QUEUED,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }
                save_state(gcs_client, job_id, state)

            # Process
            final_state = process_job(gcs_client, publisher, state)

            # Ack only if completed
            if ack_id and final_state.get("status") in TERMINAL_STATES:
                ack_job(subscriber, SUBSCRIPTION, ack_id)

        except Exception as e:
            logger.error(f"Job error: {e}", exc_info=True)
            time.sleep(5)

    logger.info("=== Heavy Job Runner Shutdown ===")


if __name__ == "__main__":
    main()
