"""Batch Grand Audit via Vertex AI / AI Studio Batch Prediction.

Submits Grand Audit requests as batch jobs, which:
- Has no output truncation (results written as full JSONL)
- Runs at 50% discount vs real-time inference
- Handles retries automatically with 24hr SLA
- Supports thinking_config (Deep Think) in request JSONL

Two modes:
- AI Studio (primary): Upload JSONL via files.upload(), batch via batches.create()
  No GCS needed. Works on any machine with GEMINI_API_KEY.
- Vertex AI (fallback): Requires GCS bucket + ADC. Better for production.
"""

import asyncio
import json
import logging
import os
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from google import genai
from google.genai.types import (
    CreateBatchJobConfig,
    HttpOptions,
    JobState,
    UploadFileConfig,
)

from planning_server.app import config

logger = logging.getLogger(__name__)

# ─── Configuration ───────────────────────────────────────────────────

GCP_PROJECT = os.getenv("GCP_PROJECT", getattr(config, "GCP_PROJECT_ID", "")) or "nl2bot-f7e604"
GCS_BUCKET = os.getenv("GCS_AUDIT_BUCKET", "nl2bot-f7e604-backup")
GCS_PREFIX = "grand_audit/jobs"

# Batch prediction models — must be Pro tier for Grand Audit
BATCH_MODEL = "gemini-3.1-pro-preview"
BATCH_FALLBACK = "gemini-3-pro-preview"

# Poll interval and timeout
POLL_INTERVAL_SECONDS = 30
POLL_TIMEOUT_SECONDS = 3600  # 1 hour max

# Pub/Sub topic for batch completion notifications (optional)
PUBSUB_TOPIC = os.getenv("GRAND_AUDIT_PUBSUB_TOPIC", "")

COMPLETED_STATES = {
    JobState.JOB_STATE_SUCCEEDED,
    JobState.JOB_STATE_FAILED,
    JobState.JOB_STATE_CANCELLED,
    JobState.JOB_STATE_PAUSED,
}


# ─── Client Helpers ──────────────────────────────────────────────────

def _get_aistudio_client() -> genai.Client:
    """AI Studio client (API key). No GCS/ADC needed."""
    api_key = config.GEMINI_API_KEY
    if not api_key:
        raise ValueError("GEMINI_API_KEY not set — needed for batch prediction")
    return genai.Client(api_key=api_key)


def _get_vertex_batch_client() -> genai.Client:
    """Vertex AI client for batch (v1 API, global endpoint)."""
    return genai.Client(
        vertexai=True,
        project=GCP_PROJECT,
        location="global",
        http_options=HttpOptions(api_version="v1"),
    )


# ─── Request Builder ─────────────────────────────────────────────────

def build_audit_request(
    prompt: str,
    system: str,
    tool_schema: dict,
    thinking_level: str = "HIGH",
    max_output_tokens: int = 65536,
) -> dict:
    """Build a single GenerateContentRequest for batch JSONL.

    The request follows the Gemini API format with thinking_config
    embedded in generation_config.
    """
    full_prompt = (
        f"{system}\n\n{prompt}\n\n"
        f"Respond with a valid JSON object matching this schema:\n"
        f"{json.dumps(tool_schema, indent=2)}"
    )

    request = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": full_prompt}],
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "maxOutputTokens": max_output_tokens,
            "thinkingConfig": {
                "thinkingLevel": thinking_level,
            },
        },
    }

    return {"request": request}


def _write_jsonl(requests: list[dict]) -> str:
    """Write requests to a temp JSONL file. Returns file path."""
    tf = tempfile.NamedTemporaryFile(
        mode="w", suffix=".jsonl", delete=False, encoding="utf-8",
    )
    for req in requests:
        tf.write(json.dumps(req, ensure_ascii=False) + "\n")
    tf.close()
    logger.info(f"[BATCH] Wrote {len(requests)} requests to {tf.name}")
    return tf.name


# ─── Batch Job Management (AI Studio) ───────────────────────────────

async def submit_batch_aistudio(
    requests: list[dict],
    job_id: str | None = None,
    model: str | None = None,
) -> dict:
    """Submit batch job via AI Studio (file upload, no GCS needed)."""
    job_id = job_id or f"audit-{uuid.uuid4().hex[:12]}"
    model = model or BATCH_MODEL

    # Write JSONL
    jsonl_path = _write_jsonl(requests)

    try:
        client = _get_aistudio_client()

        # Upload JSONL file
        logger.info(f"[BATCH/AIStudio] Uploading JSONL ({os.path.getsize(jsonl_path)} bytes)...")
        uploaded = client.files.upload(
            file=jsonl_path,
            config=UploadFileConfig(mime_type="application/jsonl"),
        )
        logger.info(f"[BATCH/AIStudio] Uploaded: {uploaded.name}")

        # Create batch job
        logger.info(f"[BATCH/AIStudio] Creating batch job: model={model}")
        job = client.batches.create(
            model=model,
            src=uploaded.name,
            config=CreateBatchJobConfig(display_name=f"grand-audit-{job_id}"),
        )
        logger.info(f"[BATCH/AIStudio] Job created: {job.name} (state={job.state})")

        return {
            "job_name": job.name,
            "job_id": job_id,
            "file_name": uploaded.name,
            "state": str(job.state),
            "model": model,
            "backend": "aistudio",
        }
    finally:
        os.unlink(jsonl_path)


async def submit_batch_vertex(
    requests: list[dict],
    job_id: str | None = None,
    model: str | None = None,
) -> dict:
    """Submit batch job via Vertex AI (requires GCS bucket)."""
    job_id = job_id or f"audit-{uuid.uuid4().hex[:12]}"
    model = model or BATCH_MODEL
    input_path = f"{GCS_PREFIX}/{job_id}/input.jsonl"
    output_uri = f"gs://{GCS_BUCKET}/{GCS_PREFIX}/{job_id}/output/"

    # Upload to GCS
    from google.cloud import storage
    gcs_client = storage.Client(project=GCP_PROJECT)
    bucket = gcs_client.bucket(GCS_BUCKET)
    blob = bucket.blob(input_path)
    content = "\n".join(json.dumps(r, ensure_ascii=False) for r in requests)
    blob.upload_from_string(content, content_type="application/jsonl")
    input_uri = f"gs://{GCS_BUCKET}/{input_path}"
    logger.info(f"[BATCH/Vertex] Uploaded to {input_uri}")

    # Create batch job
    client = _get_vertex_batch_client()
    job = client.batches.create(
        model=model,
        src=input_uri,
        config=CreateBatchJobConfig(dest=output_uri),
    )
    logger.info(f"[BATCH/Vertex] Job created: {job.name} (state={job.state})")

    return {
        "job_name": job.name,
        "job_id": job_id,
        "input_uri": input_uri,
        "output_uri": output_uri,
        "state": str(job.state),
        "model": model,
        "backend": "vertex",
    }


async def submit_batch(
    requests: list[dict],
    job_id: str | None = None,
    model: str | None = None,
) -> dict:
    """Submit batch job — tries AI Studio first (no GCS), then Vertex AI."""
    # AI Studio path — works on any machine with API key
    if config.GEMINI_API_KEY:
        try:
            return await submit_batch_aistudio(requests, job_id, model)
        except Exception as e:
            logger.warning(f"[BATCH] AI Studio submit failed: {e}")

    # Vertex AI path — needs GCS + ADC
    if GCP_PROJECT:
        return await submit_batch_vertex(requests, job_id, model)

    raise RuntimeError("No batch backend available (need GEMINI_API_KEY or GCP_PROJECT)")


# ─── Polling ─────────────────────────────────────────────────────────

async def poll_batch_job(
    job_name: str,
    backend: str = "aistudio",
    timeout: int = POLL_TIMEOUT_SECONDS,
    interval: int = POLL_INTERVAL_SECONDS,
) -> dict:
    """Poll batch job until completion."""
    client = _get_aistudio_client() if backend == "aistudio" else _get_vertex_batch_client()
    start = time.time()

    while True:
        job = client.batches.get(name=job_name)
        state = job.state
        elapsed = int(time.time() - start)
        logger.info(f"[BATCH] Job {job_name}: state={state} (elapsed={elapsed}s)")

        if state in COMPLETED_STATES:
            result = {
                "state": str(state),
                "elapsed_seconds": elapsed,
                "job_name": job_name,
            }
            if state == JobState.JOB_STATE_SUCCEEDED:
                logger.info(f"[BATCH] Job succeeded in {elapsed}s")
            else:
                logger.warning(f"[BATCH] Job ended with state={state}")
                result["error"] = f"Batch job ended with state: {state}"
            return result

        if elapsed > timeout:
            logger.error(f"[BATCH] Job timed out after {elapsed}s")
            return {
                "state": str(state),
                "elapsed_seconds": elapsed,
                "job_name": job_name,
                "error": f"Timeout after {elapsed}s",
            }

        await asyncio.sleep(interval)


# ─── Result Fetching ─────────────────────────────────────────────────

async def fetch_batch_results(
    job_name: str,
    backend: str = "aistudio",
) -> list[dict]:
    """Download and parse batch results.

    For AI Studio: results are embedded in the job object.
    For Vertex AI: results are in GCS output JSONL.
    """
    client = _get_aistudio_client() if backend == "aistudio" else _get_vertex_batch_client()
    job = client.batches.get(name=job_name)

    parsed = []

    # AI Studio: results may be in job.dest or need to download output file
    if hasattr(job, "dest") and job.dest:
        dest = job.dest
        # dest could be a file name or inline results
        if hasattr(dest, "file_name") and dest.file_name:
            # Download the output file
            try:
                content = client.files.download(name=dest.file_name)
                for line in content.strip().split("\n"):
                    if line.strip():
                        entry = json.loads(line)
                        _parse_batch_entry(entry, parsed)
                logger.info(f"[BATCH] Downloaded results from file: {dest.file_name}")
            except Exception as e:
                logger.warning(f"[BATCH] Failed to download result file: {e}")

    # Try to get results from job response directly
    if not parsed and hasattr(job, "responses"):
        for resp in job.responses:
            _parse_batch_entry(resp, parsed)

    # Vertex AI: download from GCS
    if not parsed and backend == "vertex":
        try:
            from google.cloud import storage
            gcs = storage.Client(project=GCP_PROJECT)
            bucket = gcs.bucket(GCS_BUCKET)
            # Find output files
            prefix = job_name.split("/")[-1] if "/" in job_name else job_name
            for blob in bucket.list_blobs(prefix=f"{GCS_PREFIX}/"):
                if "output" in blob.name and blob.name.endswith(".jsonl"):
                    content = blob.download_as_text()
                    for line in content.strip().split("\n"):
                        if line.strip():
                            entry = json.loads(line)
                            _parse_batch_entry(entry, parsed)
        except Exception as e:
            logger.warning(f"[BATCH] GCS download failed: {e}")

    logger.info(f"[BATCH] Parsed {len(parsed)} results")
    return parsed


def _parse_batch_entry(entry: dict, parsed: list[dict]) -> None:
    """Parse a single batch output entry into structured result."""
    response = entry.get("response", entry)
    candidates = response.get("candidates", [])
    if candidates:
        content = candidates[0].get("content", {})
        parts = content.get("parts", [])
        for part in parts:
            text = part.get("text", "")
            if text:
                try:
                    parsed.append(json.loads(text))
                except json.JSONDecodeError:
                    logger.warning(f"[BATCH] Non-JSON response: {text[:200]}")
                    parsed.append({"_raw_text": text})
    elif "status" in entry or "error" in entry:
        parsed.append({"_error": entry.get("status", entry.get("error"))})


# ─── Pub/Sub Notification ───────────────────────────────────────────

async def publish_completion(job_id: str, result: dict, topic: str | None = None) -> None:
    """Publish batch job completion event to Pub/Sub (optional)."""
    topic = topic or PUBSUB_TOPIC
    if not topic:
        return

    try:
        from google.cloud import pubsub_v1
        publisher = pubsub_v1.PublisherClient()
        message = json.dumps({
            "event": "grand_audit_complete",
            "job_id": job_id,
            "state": result.get("state"),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }).encode("utf-8")
        future = publisher.publish(topic, message)
        msg_id = future.result(timeout=10)
        logger.info(f"[PUBSUB] Published: {msg_id}")
    except Exception as e:
        logger.warning(f"[PUBSUB] Failed: {e}")


# ─── High-Level API ──────────────────────────────────────────────────

async def run_batch_grand_audit(
    prompt: str,
    system: str,
    tool_schema: dict,
    model: str | None = None,
    thinking_level: str = "HIGH",
    max_output_tokens: int = 65536,
    job_id: str | None = None,
) -> tuple[str, dict[str, Any]]:
    """Run Grand Audit via batch prediction. No output truncation.

    Tries AI Studio first (file upload, no GCS), then Vertex AI (GCS).
    Falls back to secondary model on failure.

    Returns:
        (model_used, parsed_result) tuple.
    """
    model = model or BATCH_MODEL

    # Build request
    request = build_audit_request(
        prompt=prompt,
        system=system,
        tool_schema=tool_schema,
        thinking_level=thinking_level,
        max_output_tokens=max_output_tokens,
    )

    # Submit
    job_info = await submit_batch([request], job_id=job_id, model=model)
    job_name = job_info["job_name"]
    batch_job_id = job_info["job_id"]
    backend = job_info["backend"]

    # Poll
    poll_result = await poll_batch_job(job_name, backend=backend)

    # Notify
    await publish_completion(batch_job_id, poll_result)

    if poll_result.get("error"):
        # Try fallback model
        if model == BATCH_MODEL and BATCH_FALLBACK:
            logger.warning(f"[BATCH] Primary model failed, trying fallback: {BATCH_FALLBACK}")
            return await run_batch_grand_audit(
                prompt=prompt,
                system=system,
                tool_schema=tool_schema,
                model=BATCH_FALLBACK,
                thinking_level=thinking_level,
                max_output_tokens=max_output_tokens,
                job_id=f"{batch_job_id}-fb",
            )
        raise RuntimeError(f"Batch job failed: {poll_result}")

    # Fetch results
    results = await fetch_batch_results(job_name, backend=backend)
    if not results:
        raise RuntimeError(f"No results from batch job {batch_job_id}")

    model_tag = f"{model} [batch][DeepThink={thinking_level}][{backend}]"
    logger.info(f"[BATCH] Complete via {model_tag} in {poll_result.get('elapsed_seconds', '?')}s")

    return model_tag, results[0]
