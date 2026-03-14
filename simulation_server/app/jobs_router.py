"""Jobs management — full simulation pipeline endpoint."""

import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse

from shared.schemas.simulation_request import SimulationRequest
from shared.schemas.simulation_feedback import (
    SimulationFeedback,
    RenderResult,
    AssemblyResult,
    PrintabilityResult,
    FeedbackItem,
    SeverityLevel,
)
from simulation_server.app import config
from simulation_server.app.renderer.openscad import render_scad_to_stl
from simulation_server.app.renderer.stl_utils import analyze_stl
from simulation_server.app.assembler.urdf_gen import generate_urdf
from simulation_server.app.analyzer.printability import check_printability
from simulation_server.app.analyzer.collision import check_collisions

logger = logging.getLogger(__name__)
router = APIRouter()

# In-memory job tracking (replace with DB for production)
_jobs: dict[str, dict] = {}


async def _run_simulation(request: SimulationRequest):
    """Execute the full simulation pipeline."""
    job_id = request.job_id
    job_dir = config.JOBS_DIR / job_id
    input_dir = job_dir / "input"
    output_dir = job_dir / "output"
    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    _jobs[job_id]["status"] = "running"
    sim_type = request.simulation_type
    feedback_items: list[FeedbackItem] = []
    render_results: list[RenderResult] = []
    printability_results: list[PrintabilityResult] = []
    assembly_result = None
    overall_score = 1.0

    robot = request.robot_spec

    try:
        # Step 1: Render SCAD → STL
        if sim_type in ("render", "full"):
            _jobs[job_id]["step"] = "rendering"
            for part in robot.parts:
                if not part.scad_code.strip():
                    feedback_items.append(FeedbackItem(
                        category="render",
                        severity=SeverityLevel.WARNING,
                        part_id=part.id,
                        message=f"No SCAD code for part '{part.id}', skipping render.",
                        data={},
                    ))
                    continue

                stl_path = output_dir / f"{part.id}.stl"
                # Save SCAD source
                scad_path = input_dir / f"{part.id}.scad"
                scad_path.write_text(part.scad_code)

                success, message = await render_scad_to_stl(
                    scad_code=part.scad_code,
                    output_path=stl_path,
                )

                if success:
                    analysis = analyze_stl(stl_path)
                    render_results.append(RenderResult(
                        part_id=part.id,
                        stl_path=str(stl_path),
                        stl_size_bytes=analysis.get("stl_size_bytes", 0),
                        dimensions_mm=analysis.get("dimensions_mm", (0, 0, 0)),
                        volume_mm3=analysis.get("volume_mm3", 0),
                        is_manifold=analysis.get("is_manifold", False),
                        triangle_count=analysis.get("triangle_count", 0),
                    ))
                else:
                    overall_score -= 0.2
                    feedback_items.append(FeedbackItem(
                        category="render",
                        severity=SeverityLevel.ERROR,
                        part_id=part.id,
                        message=f"Render failed for '{part.id}': {message}",
                        data={},
                        suggestion="Check OpenSCAD syntax and module dependencies.",
                    ))

        # Step 2: Printability analysis
        if sim_type in ("render", "full"):
            _jobs[job_id]["step"] = "printability"
            for rr in render_results:
                stl_path = Path(rr.stl_path)
                if stl_path.exists():
                    pr, fb = check_printability(
                        stl_path=stl_path,
                        part_id=rr.part_id,
                        printer=robot.printer,
                    )
                    printability_results.append(pr)
                    feedback_items.extend(fb)
                    if not pr.fits_build_volume:
                        overall_score -= 0.15

        # Step 3: URDF assembly
        if sim_type in ("assemble", "full") and render_results:
            _jobs[job_id]["step"] = "assembling"
            urdf_path = output_dir / f"{robot.name.replace(' ', '_').lower()}.urdf"
            try:
                generate_urdf(robot, stl_dir=output_dir, output_path=urdf_path)
                total_mass = sum(p.mass_grams for p in robot.parts)
                assembly_result = AssemblyResult(
                    urdf_path=str(urdf_path),
                    total_mass_grams=total_mass,
                    center_of_mass=(0.0, 0.0, 0.0),
                    viewer_url=f"/api/v1/viewer/{job_id}",
                )
            except Exception as e:
                overall_score -= 0.1
                feedback_items.append(FeedbackItem(
                    category="assembly",
                    severity=SeverityLevel.ERROR,
                    message=f"URDF assembly failed: {e}",
                    data={},
                ))

        # Step 4: Collision detection
        if sim_type == "full" and render_results:
            _jobs[job_id]["step"] = "collision_check"
            stl_paths = {}
            for rr in render_results:
                p = Path(rr.stl_path)
                if p.exists():
                    stl_paths[rr.part_id] = p
            collision_feedback = check_collisions(stl_paths)
            feedback_items.extend(collision_feedback)
            if collision_feedback:
                overall_score -= 0.1 * len(collision_feedback)

        # Clamp score
        overall_score = max(0.0, min(1.0, overall_score))

        feedback = SimulationFeedback(
            job_id=job_id,
            status="completed",
            render_results=render_results,
            assembly_result=assembly_result,
            printability_results=printability_results,
            feedback_items=feedback_items,
            overall_score=round(overall_score, 2),
        )

    except Exception as e:
        logger.exception(f"Simulation failed for job {job_id}")
        feedback = SimulationFeedback(
            job_id=job_id,
            status="failed",
            feedback_items=[FeedbackItem(
                category="system",
                severity=SeverityLevel.CRITICAL,
                message=f"Simulation crashed: {e}",
                data={},
            )],
            overall_score=0.0,
        )

    # Save feedback
    feedback_path = job_dir / "feedback.json"
    feedback_path.write_text(feedback.model_dump_json(indent=2))
    _jobs[job_id]["status"] = feedback.status
    _jobs[job_id]["step"] = "done"
    _jobs[job_id]["feedback"] = feedback.model_dump()

    # Callback if requested
    if request.callback_url:
        try:
            import httpx
            async with httpx.AsyncClient() as client:
                await client.post(
                    request.callback_url,
                    json=feedback.model_dump(),
                    timeout=30,
                )
        except Exception as e:
            logger.warning(f"Callback to {request.callback_url} failed: {e}")


@router.post("/simulate")
async def submit_simulation(request: SimulationRequest, background_tasks: BackgroundTasks):
    """Submit a simulation job."""
    if not request.job_id:
        request.job_id = str(uuid.uuid4())

    _jobs[request.job_id] = {
        "status": "queued",
        "step": "pending",
        "submitted_at": datetime.now(timezone.utc).isoformat(),
        "simulation_type": request.simulation_type,
    }

    background_tasks.add_task(_run_simulation, request)

    return {
        "job_id": request.job_id,
        "status": "queued",
        "message": "Simulation job submitted.",
    }


@router.get("/jobs/{job_id}")
async def get_job_status(job_id: str):
    """Get job status."""
    if job_id not in _jobs:
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' not found")
    job = _jobs[job_id]
    return {
        "job_id": job_id,
        "status": job["status"],
        "step": job.get("step", "unknown"),
    }


@router.get("/jobs/{job_id}/feedback")
async def get_job_feedback(job_id: str):
    """Get structured feedback for a completed job."""
    # Try in-memory first
    if job_id in _jobs and "feedback" in _jobs[job_id]:
        return _jobs[job_id]["feedback"]

    # Try from file
    feedback_path = config.JOBS_DIR / job_id / "feedback.json"
    if feedback_path.exists():
        return json.loads(feedback_path.read_text())

    raise HTTPException(status_code=404, detail=f"No feedback for job '{job_id}'")


@router.get("/jobs/{job_id}/stl/{part_id}")
async def download_stl(job_id: str, part_id: str):
    """Download an STL file for a specific part."""
    stl_path = config.JOBS_DIR / job_id / "output" / f"{part_id}.stl"
    if not stl_path.exists():
        raise HTTPException(status_code=404, detail=f"STL not found: {part_id}")
    return FileResponse(
        str(stl_path),
        media_type="application/sla",
        filename=f"{part_id}.stl",
    )


@router.get("/jobs/{job_id}/urdf")
async def download_urdf(job_id: str):
    """Download the URDF file for a job."""
    output_dir = config.JOBS_DIR / job_id / "output"
    if not output_dir.exists():
        raise HTTPException(status_code=404, detail=f"Job output not found: {job_id}")

    urdf_files = list(output_dir.glob("*.urdf"))
    if not urdf_files:
        raise HTTPException(status_code=404, detail="No URDF file generated")

    return FileResponse(
        str(urdf_files[0]),
        media_type="application/xml",
        filename=urdf_files[0].name,
    )


@router.delete("/jobs/{job_id}")
async def delete_job(job_id: str):
    """Clean up job data."""
    import shutil

    job_dir = config.JOBS_DIR / job_id
    if job_dir.exists():
        shutil.rmtree(job_dir)
    _jobs.pop(job_id, None)
    return {"message": f"Job '{job_id}' deleted."}
