"""Pipeline execution endpoints."""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from planning_server.app.database import get_db, User
from planning_server.app.auth.dependencies import get_current_user
from planning_server.app.pipeline.orchestrator import run_pipeline, PipelineProgress

router = APIRouter(tags=["pipeline"])

# In-memory pipeline tracking
_pipelines: dict[str, dict] = {}


class PipelineRunRequest(BaseModel):
    prompt: str = Field(min_length=10, description="Natural language description of the robot")
    model: str | None = Field(default=None, description="Claude model override")


class PipelineStatusResponse(BaseModel):
    status: str
    current_step: str = ""
    progress: float = 0.0
    errors: list[str] = Field(default_factory=list)


async def _run_pipeline_task(prompt: str, project_id: int, pipeline_key: str):
    """Background task for pipeline execution."""
    progress = PipelineProgress()
    _pipelines[pipeline_key]["progress"] = progress

    try:
        results = await run_pipeline(prompt, project_id, progress)
        _pipelines[pipeline_key]["status"] = "completed"
        _pipelines[pipeline_key]["results"] = results
    except Exception as e:
        _pipelines[pipeline_key]["status"] = "failed"
        _pipelines[pipeline_key]["error"] = str(e)


@router.post("/projects/{project_id}/pipeline/run")
async def start_pipeline(
    project_id: int,
    request: PipelineRunRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
):
    pipeline_key = f"{project_id}_{current_user.id}"
    _pipelines[pipeline_key] = {
        "status": "running",
        "project_id": project_id,
        "prompt": request.prompt,
    }

    background_tasks.add_task(_run_pipeline_task, request.prompt, project_id, pipeline_key)

    return {"status": "started", "message": "Pipeline started in background."}


@router.get("/projects/{project_id}/pipeline/status", response_model=PipelineStatusResponse)
async def get_pipeline_status(
    project_id: int,
    current_user: User = Depends(get_current_user),
):
    pipeline_key = f"{project_id}_{current_user.id}"
    pipeline = _pipelines.get(pipeline_key)

    if not pipeline:
        return PipelineStatusResponse(status="not_started")

    progress = pipeline.get("progress")
    if progress:
        return PipelineStatusResponse(
            status=pipeline["status"],
            current_step=progress.current_step,
            progress=progress.current_progress,
            errors=[progress.error] if progress.error else [],
        )

    return PipelineStatusResponse(status=pipeline["status"])


@router.get("/projects/{project_id}/pipeline/results")
async def get_pipeline_results(
    project_id: int,
    current_user: User = Depends(get_current_user),
):
    pipeline_key = f"{project_id}_{current_user.id}"
    pipeline = _pipelines.get(pipeline_key)

    if not pipeline:
        raise HTTPException(status_code=404, detail="No pipeline run found")

    if pipeline["status"] != "completed":
        raise HTTPException(status_code=202, detail=f"Pipeline status: {pipeline['status']}")

    return pipeline.get("results", {})
