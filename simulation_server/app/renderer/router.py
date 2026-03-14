"""Renderer API endpoints."""

import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from simulation_server.app import config
from simulation_server.app.renderer.openscad import render_scad_to_stl
from simulation_server.app.renderer.stl_utils import analyze_stl

router = APIRouter()


class RenderRequest(BaseModel):
    scad_code: str = Field(description="OpenSCAD source code")
    parameters: dict = Field(default_factory=dict, description="OpenSCAD variable overrides")
    part_id: str = Field(default="unnamed", description="Part identifier")


class RenderResponse(BaseModel):
    success: bool
    part_id: str
    message: str
    stl_path: str = ""
    analysis: dict = Field(default_factory=dict)


@router.post("/render", response_model=RenderResponse)
async def render_single(request: RenderRequest):
    """Render a single SCAD file to STL and return analysis."""
    job_id = str(uuid.uuid4())[:8]
    job_dir = config.JOBS_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    output_path = job_dir / f"{request.part_id}.stl"

    success, message = await render_scad_to_stl(
        scad_code=request.scad_code,
        output_path=output_path,
        parameters=request.parameters,
    )

    analysis = {}
    if success and output_path.exists():
        analysis = analyze_stl(output_path)

    return RenderResponse(
        success=success,
        part_id=request.part_id,
        message=message,
        stl_path=str(output_path) if success else "",
        analysis=analysis,
    )
