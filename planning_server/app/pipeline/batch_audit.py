"""Batch Grand Audit via Vertex AI Batch Prediction + GCS + Pub/Sub.

Submits Grand Audit requests as batch jobs to Vertex AI, which:
- Has no output truncation (results written to GCS as full JSONL)
- Runs at 50% discount vs real-time inference
- Handles retries automatically with 24hr SLA
- Supports thinking_config (Deep Think) in request JSONL

Architecture:
    1. Build JSONL request → upload to gs://{bucket}/grand_audit/jobs/{job_id}/input.jsonl
    2. Submit batch job via client.batches.create()
    3. Poll via client.batches.get() OR receive Pub/Sub notification
    4. Download results from gs://{bucket}/grand_audit/jobs/{job_id}/output/
    5. Parse response JSONL → return structured audit result
"""

import asyncio
import json
import logging
import os
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from google import genai
from google.genai.types import CreateBatchJobConfig, HttpOptions, JobState

from planning_server.app import config

logger = logging.getLogger(__name__)

# ─── Configuration ───────────────────────────────────────────────────

GCS_BUCKET = os.getenv("GCS_AUDIT_BUCKET", "nl2bot-f7e604-backup")
GCS_PREFIX = "grand_audit/jobs"
GCP_PROJECT = os.getenv("GCP_PROJECT", getattr(config, "GCP_PROJECT_ID", ""))

# Batch prediction models — must be Pro tier for Grand Audit
BATCH_MODEL = "gemini-3.1-pro-preview"
BATCH_FALLBACK = "gemini-3-pro-preview"

# Poll interval and timeout
POLL_INTERVAL_SECONDS = 30
POLL_TIMEOUT_SECONDS = 3600  # 1 hour max (batch usually completes in minutes)

# Pub/Sub topic for batch completion notifications (optional)
PUBSUB_TOPIC = os.getenv("GRAND_AUDIT_PUBSUB_TOPIC", "")  # e.g. "projects/nl2bot-f7e604/topics/grand-audit-done"

COMPLETED_STATES = {
    JobState.JOB_STATE_SUCCEEDED,
    JobState.JOB_STATE_FAILED,
    JobState.JOB_STATE_CANCELLED,
    JobState.JOB_STATE_PAUSED,
}


# ─── GCS Helpers ─────────────────────────────────────────────────────

def _get_gcs_client():
    """Get Google Cloud Storage client."""
    from google.cloud import storage
    return storage.Client(project=GCP_PROJECT)


def _upload_jsonl(bucket_name: str, blob_path: str, lines: list[dict]) -> str:
    """Upload JSONL to GCS. Returns gs:// URI."""
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_path)
    content = "\n".join(json.dumps(line, ensure_ascii=False) for line in lines)
    blob.upload_from_string(content, content_type="application/jsonl")
    uri = f"gs://{bucket_name}/{blob_path}"
    logger.info(f"[BATCH] Uploaded {len(lines)} requests to {uri} ({len(content)} bytes)")
    return uri


def _download_jsonl(bucket_name: str, prefix: str) -> list[dict]:
    """Download all JSONL files from GCS prefix. Returns parsed lines."""
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    results = []
    for blob in bucket.list_blobs(prefix=prefix):
        if blob.name.endswith(".jsonl"):
            content = blob.download_as_text()
            for line in content.strip().split("\n"):
                if line.strip():
                    results.append(json.loads(line))
            logger.info(f"[BATCH] Downloaded {blob.name} ({len(content)} bytes)")
    return results


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
    embedded in generation_config (not as a separate field).
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


# ─── Batch Job Management ───────────────────────────────────────────

def _get_batch_client() -> genai.Client:
    """Get genai client for batch operations (Vertex AI only, v1 API)."""
    return genai.Client(
        vertexai=True,
        project=GCP_PROJECT,
        location="global",
        http_options=HttpOptions(api_version="v1"),
    )


async def submit_batch_audit(
    requests: list[dict],
    job_id: str | None = None,
    model: str | None = None,
) -> dict:
    """Submit batch audit job to Vertex AI.

    Args:
        requests: List of GenerateContentRequest dicts (from build_audit_request).
        job_id: Optional job ID (auto-generated if None).
        model: Model to use (defaults to BATCH_MODEL).

    Returns:
        dict with job_name, job_id, input_uri, output_uri, state.
    """
    job_id = job_id or f"audit-{uuid.uuid4().hex[:12]}"
    model = model or BATCH_MODEL
    input_path = f"{GCS_PREFIX}/{job_id}/input.jsonl"
    output_uri = f"gs://{GCS_BUCKET}/{GCS_PREFIX}/{job_id}/output/"

    # Upload input JSONL
    input_uri = _upload_jsonl(GCS_BUCKET, input_path, requests)

    # Create batch job
    client = _get_batch_client()
    logger.info(f"[BATCH] Creating batch job: model={model}, input={input_uri}, output={output_uri}")

    job = client.batches.create(
        model=model,
        src=input_uri,
        config=CreateBatchJobConfig(dest=output_uri),
    )

    logger.info(f"[BATCH] Job created: {job.name} (state={job.state})")

    return {
        "job_name": job.name,
        "job_id": job_id,
        "input_uri": input_uri,
        "output_uri": output_uri,
        "state": str(job.state),
        "model": model,
    }


async def poll_batch_job(
    job_name: str,
    timeout: int = POLL_TIMEOUT_SECONDS,
    interval: int = POLL_INTERVAL_SECONDS,
) -> dict:
    """Poll batch job until completion.

    Returns:
        dict with state, output_uri, error (if any).
    """
    client = _get_batch_client()
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


async def fetch_batch_results(
    job_id: str,
) -> list[dict]:
    """Download and parse batch output JSONL from GCS.

    Returns list of parsed response dicts.
    """
    output_prefix = f"{GCS_PREFIX}/{job_id}/output/"
    raw_results = _download_jsonl(GCS_BUCKET, output_prefix)

    parsed = []
    for entry in raw_results:
        # Batch output format: {"response": {...}, "status": "..."} per line
        response = entry.get("response", {})
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
        elif "status" in entry:
            # Error entry
            parsed.append({"_error": entry["status"]})

    logger.info(f"[BATCH] Parsed {len(parsed)} results from {len(raw_results)} raw entries")
    return parsed


# ─── Pub/Sub Notification (Optional) ────────────────────────────────

async def setup_pubsub_notification(topic: str | None = None) -> str | None:
    """Create Pub/Sub topic for batch completion notifications if it doesn't exist.

    Returns topic name or None if Pub/Sub not configured.
    """
    topic = topic or PUBSUB_TOPIC
    if not topic:
        return None

    try:
        from google.cloud import pubsub_v1
        publisher = pubsub_v1.PublisherClient()

        try:
            publisher.get_topic(topic=topic)
            logger.info(f"[PUBSUB] Topic exists: {topic}")
        except Exception:
            # Extract project from topic name: projects/{project}/topics/{name}
            publisher.create_topic(name=topic)
            logger.info(f"[PUBSUB] Created topic: {topic}")

        return topic
    except ImportError:
        logger.warning("[PUBSUB] google-cloud-pubsub not installed, skipping")
        return None
    except Exception as e:
        logger.warning(f"[PUBSUB] Failed to setup topic: {e}")
        return None


async def publish_completion(job_id: str, result: dict, topic: str | None = None) -> None:
    """Publish batch job completion event to Pub/Sub."""
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
        logger.info(f"[PUBSUB] Published completion event: {msg_id}")
    except Exception as e:
        logger.warning(f"[PUBSUB] Failed to publish: {e}")


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

    This is the batch equivalent of _call_with_cascade() — submits to GCS,
    waits for completion, downloads full untruncated results.

    Args:
        prompt: Full audit prompt.
        system: System prompt.
        tool_schema: JSON schema for structured output.
        model: Model ID (defaults to gemini-3.1-pro-preview).
        thinking_level: Deep Think level.
        max_output_tokens: Max output (batch supports much higher limits).
        job_id: Optional job ID.

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

    # Submit batch
    job_info = await submit_batch_audit([request], job_id=job_id, model=model)
    job_name = job_info["job_name"]
    batch_job_id = job_info["job_id"]

    # Poll until done
    poll_result = await poll_batch_job(job_name)

    # Notify via Pub/Sub
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

    # Download results
    results = await fetch_batch_results(batch_job_id)
    if not results:
        raise RuntimeError(f"No results from batch job {batch_job_id}")

    model_tag = f"{model} [batch][DeepThink={thinking_level}]"
    logger.info(f"[BATCH] Grand Audit complete via {model_tag} in {poll_result.get('elapsed_seconds', '?')}s")

    return model_tag, results[0]
