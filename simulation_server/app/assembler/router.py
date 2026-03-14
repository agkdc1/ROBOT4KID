"""Assembler API endpoints."""

from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from shared.schemas.robot_spec import RobotSpec
from simulation_server.app import config
from simulation_server.app.assembler.urdf_gen import generate_urdf

router = APIRouter()


class AssembleRequest(BaseModel):
    job_id: str
    robot_spec: RobotSpec


class AssembleResponse(BaseModel):
    success: bool
    urdf_path: str = ""
    message: str = ""


@router.post("/assemble", response_model=AssembleResponse)
async def assemble_urdf(request: AssembleRequest):
    """Generate URDF from RobotSpec and rendered STL files."""
    job_dir = config.JOBS_DIR / request.job_id
    if not job_dir.exists():
        raise HTTPException(status_code=404, detail=f"Job directory not found: {request.job_id}")

    output_dir = job_dir / "output"
    output_dir.mkdir(exist_ok=True)
    stl_dir = output_dir  # STLs are rendered here
    urdf_path = output_dir / f"{request.robot_spec.name.replace(' ', '_').lower()}.urdf"

    try:
        result_path = generate_urdf(
            robot_spec=request.robot_spec,
            stl_dir=stl_dir,
            output_path=urdf_path,
        )
        return AssembleResponse(success=True, urdf_path=result_path, message="URDF generated")
    except Exception as e:
        return AssembleResponse(success=False, message=f"URDF generation failed: {e}")
