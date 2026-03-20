"""Cloud Run Job trigger — Pub/Sub push subscription calls this to execute heavy-worker."""

import base64
import json
import logging
import os

from fastapi import APIRouter, Request, HTTPException

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/jobs", tags=["jobs"])

GCP_PROJECT = os.getenv("GCP_PROJECT", "")
GCP_REGION = os.getenv("GCP_REGION", "us-west1")


@router.post("/trigger")
async def trigger_heavy_worker(request: Request):
    """Called by Pub/Sub push subscription when a heavy-jobs message arrives.
    Executes the heavy-worker Cloud Run Job."""
    if os.getenv("ENVIRONMENT") != "cloud":
        raise HTTPException(400, "Only available in cloud mode")

    # Parse Pub/Sub push message (optional — just for logging)
    try:
        body = await request.json()
        message = body.get("message", {})
        data = base64.b64decode(message.get("data", "")).decode()
        job_data = json.loads(data)
        job_id = job_data.get("job_id", "unknown")
        logger.info(f"[TRIGGER] Heavy job requested: {job_id}")
    except Exception:
        job_id = "unknown"
        logger.info("[TRIGGER] Heavy job requested (could not parse message)")

    # Execute Cloud Run Job
    try:
        from google.cloud import run_v2

        client = run_v2.JobsClient()
        job_name = f"projects/{GCP_PROJECT}/locations/{GCP_REGION}/jobs/heavy-worker"
        operation = client.run_job(name=job_name)
        logger.info(f"[TRIGGER] Job execution started for {job_id}")
        return {"status": "triggered", "job_id": job_id}
    except Exception as e:
        logger.error(f"[TRIGGER] Failed to execute job: {e}")
        raise HTTPException(500, f"Failed to trigger job: {e}")
