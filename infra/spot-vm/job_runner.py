#!/usr/bin/env python3
"""Spot VM job runner — pulls heavy jobs from Pub/Sub, executes, uploads results.

Runs on a preemptible GCE instance. Handles:
- OpenSCAD rendering (xvfb-run openscad)
- STL analysis (trimesh)
- URDF assembly
- Blender pro rendering (headless Cycles)

Lifecycle:
    1. Pull message from Pub/Sub subscription
    2. Download input files from GCS
    3. Execute job (OpenSCAD/Blender/etc.)
    4. Upload results to GCS
    5. Publish completion to job-results topic
    6. Repeat until idle for 5 minutes, then self-terminate
"""

import json
import logging
import os
import subprocess
import tempfile
import time
from pathlib import Path

from google.cloud import pubsub_v1, storage

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("job_runner")

# Config from instance metadata
GCP_PROJECT = os.environ.get("GCP_PROJECT", "")
ARTIFACTS_BUCKET = os.environ.get("GCS_ARTIFACTS_BUCKET", "")
SUBSCRIPTION = os.environ.get("HEAVY_JOBS_SUB", "")
RESULTS_TOPIC = os.environ.get("JOB_RESULTS_TOPIC", "")

# Read from instance metadata if env not set
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

IDLE_TIMEOUT = 300  # 5 minutes idle → self-terminate
WORK_DIR = Path("/tmp/jobs")


def pull_job(subscriber, subscription_path: str) -> dict | None:
    """Pull one job from Pub/Sub. Returns None if no messages."""
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


def download_inputs(gcs_client, job: dict) -> Path:
    """Download input files from GCS to local work dir."""
    job_id = job.get("job_id", "unknown")
    job_dir = WORK_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    input_prefix = job.get("input_prefix", f"jobs/{job_id}/input/")

    for blob in bucket.list_blobs(prefix=input_prefix):
        local_path = job_dir / "input" / Path(blob.name).name
        local_path.parent.mkdir(parents=True, exist_ok=True)
        blob.download_to_filename(str(local_path))
        logger.info(f"Downloaded: {blob.name} → {local_path}")

    return job_dir


def upload_outputs(gcs_client, job_dir: Path, job_id: str) -> list[str]:
    """Upload output files to GCS."""
    bucket = gcs_client.bucket(ARTIFACTS_BUCKET)
    output_dir = job_dir / "output"
    uploaded = []

    if output_dir.exists():
        for file_path in output_dir.rglob("*"):
            if file_path.is_file():
                key = f"jobs/{job_id}/output/{file_path.relative_to(output_dir)}"
                blob = bucket.blob(key)
                blob.upload_from_filename(str(file_path))
                uploaded.append(f"gs://{ARTIFACTS_BUCKET}/{key}")
                logger.info(f"Uploaded: {file_path} → {key}")

    return uploaded


def execute_openscad(job_dir: Path, params: dict) -> dict:
    """Run OpenSCAD rendering."""
    scad_file = job_dir / "input" / params.get("scad_file", "main.scad")
    output_dir = job_dir / "output"
    output_dir.mkdir(exist_ok=True)

    output_format = params.get("format", "stl")
    output_file = output_dir / f"output.{output_format}"

    cmd = ["xvfb-run", "openscad", "-o", str(output_file)]

    # Add variable overrides
    for var, val in params.get("variables", {}).items():
        cmd.extend(["-D", f"{var}={val}"])

    cmd.append(str(scad_file))

    logger.info(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

    return {
        "success": result.returncode == 0,
        "stdout": result.stdout[:1000],
        "stderr": result.stderr[:1000],
        "output_file": str(output_file) if output_file.exists() else None,
    }


def execute_blender(job_dir: Path, params: dict) -> dict:
    """Run Blender Cycles rendering."""
    stl_dir = job_dir / "input"
    output_dir = job_dir / "output"
    output_dir.mkdir(exist_ok=True)

    preset = params.get("preset", "hero")
    script = params.get("script", "/app/system/render_pro.py")

    cmd = [
        "blender", "-b", "-P", script,
        "--", "--stl-dir", str(stl_dir),
        "--output-dir", str(output_dir),
        "--preset", preset,
    ]

    logger.info(f"Running Blender: {preset}")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)

    return {
        "success": result.returncode == 0,
        "stdout": result.stdout[-500:],
        "stderr": result.stderr[-500:],
    }


def publish_result(publisher, topic: str, job_id: str, result: dict):
    """Publish job completion to Pub/Sub."""
    message = json.dumps({
        "job_id": job_id,
        "status": "completed" if result.get("success") else "failed",
        "result": result,
        "timestamp": time.time(),
    }).encode()

    future = publisher.publish(topic, message)
    msg_id = future.result(timeout=10)
    logger.info(f"Published result: {msg_id}")


def main():
    logger.info("=== Heavy Job Runner Starting ===")
    logger.info(f"Project: {GCP_PROJECT}, Bucket: {ARTIFACTS_BUCKET}")

    WORK_DIR.mkdir(parents=True, exist_ok=True)

    subscriber = pubsub_v1.SubscriberClient()
    publisher = pubsub_v1.PublisherClient()
    gcs_client = storage.Client(project=GCP_PROJECT)

    last_job_time = time.time()

    while True:
        try:
            job = pull_job(subscriber, SUBSCRIPTION)

            if job is None:
                # No jobs — check idle timeout
                idle = time.time() - last_job_time
                if idle > IDLE_TIMEOUT:
                    logger.info(f"Idle for {idle:.0f}s, shutting down")
                    break
                time.sleep(10)
                continue

            last_job_time = time.time()
            job_id = job.get("job_id", "unknown")
            job_type = job.get("type", "openscad")
            ack_id = job.pop("_ack_id", None)

            logger.info(f"Processing job {job_id} (type={job_type})")

            # Download inputs
            job_dir = download_inputs(gcs_client, job)

            # Execute
            if job_type == "openscad":
                result = execute_openscad(job_dir, job.get("params", {}))
            elif job_type == "blender":
                result = execute_blender(job_dir, job.get("params", {}))
            else:
                result = {"success": False, "error": f"Unknown job type: {job_type}"}

            # Upload outputs
            if result.get("success"):
                uploaded = upload_outputs(gcs_client, job_dir, job_id)
                result["output_files"] = uploaded

            # Publish result
            if RESULTS_TOPIC:
                publish_result(publisher, RESULTS_TOPIC, job_id, result)

            # Ack the message
            if ack_id:
                ack_job(subscriber, SUBSCRIPTION, ack_id)

            logger.info(f"Job {job_id} complete: {'OK' if result.get('success') else 'FAIL'}")

        except Exception as e:
            logger.error(f"Job error: {e}", exc_info=True)
            time.sleep(5)

    logger.info("=== Heavy Job Runner Shutdown ===")


if __name__ == "__main__":
    main()
