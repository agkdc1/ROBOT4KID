"""FCS API endpoints — shot data upload, coefficient retrieval, training."""

import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from .trajectory import (
    ShotRecord,
    TrajectoryCoefficients,
    load_coefficients,
    train_coefficients,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/fcs", tags=["fcs"])

# In-memory shot storage (persisted via training)
_shot_buffer: list[ShotRecord] = []


class ShotUpload(BaseModel):
    shots: list[ShotRecord]


@router.get("/coefficients")
async def get_coefficients() -> dict:
    """Return current trajectory coefficients."""
    coeffs = load_coefficients()
    return coeffs.model_dump()


@router.post("/shots")
async def upload_shots(data: ShotUpload) -> dict:
    """Upload shot records from tablet for RL training."""
    _shot_buffer.extend(data.shots)
    logger.info(f"Received {len(data.shots)} shots, buffer total: {len(_shot_buffer)}")
    return {"received": len(data.shots), "buffer_total": len(_shot_buffer)}


@router.post("/train")
async def trigger_training() -> dict:
    """Run RL training on buffered shots and return updated coefficients."""
    if not _shot_buffer:
        raise HTTPException(status_code=400, detail="No shot data to train on")

    current = load_coefficients()
    updated = train_coefficients(_shot_buffer, current)

    logger.info(f"Training complete on {len(_shot_buffer)} shots")
    return {
        "shots_used": len(_shot_buffer),
        "coefficients": updated.model_dump(),
    }


@router.delete("/shots")
async def clear_shots() -> dict:
    """Clear the shot buffer."""
    count = len(_shot_buffer)
    _shot_buffer.clear()
    return {"cleared": count}
