"""Project CRUD endpoints."""

import os

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from shared.db_backend import get_db_backend
from planning_server.app import config
from planning_server.app.auth.dependencies import get_current_user

router = APIRouter(prefix="/projects", tags=["projects"])


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(default="")


class ProjectResponse(BaseModel):
    id: str
    name: str
    description: str
    status: str
    owner_id: str


class ProjectUpdate(BaseModel):
    name: str | None = None
    description: str | None = None


@router.get("", response_model=list[ProjectResponse])
async def list_projects(current_user: dict = Depends(get_current_user)):
    db = get_db_backend()
    projects = await db.list_projects_by_owner(current_user["id"])
    return [
        ProjectResponse(
            id=p["id"], name=p["name"], description=p.get("description", ""),
            status=p.get("status", "active"), owner_id=p["owner_id"],
        )
        for p in projects
    ]


@router.post("", response_model=ProjectResponse, status_code=201)
async def create_project(
    request: ProjectCreate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db_backend()
    project = await db.create_project(
        name=request.name,
        description=request.description,
        owner_id=current_user["id"],
    )

    # Create project directory (local mode only)
    if os.getenv("ENVIRONMENT", "local") != "cloud":
        project_dir = config.PROJECTS_DIR / str(project["id"])
        for sub in ["conversations", "scad", "firmware", "flutter"]:
            (project_dir / sub).mkdir(parents=True, exist_ok=True)

    return ProjectResponse(
        id=project["id"], name=project["name"],
        description=project.get("description", ""),
        status=project.get("status", "active"),
        owner_id=project["owner_id"],
    )


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db_backend()
    project = await db.get_project(project_id)
    if not project or project.get("owner_id") != current_user["id"]:
        raise HTTPException(status_code=404, detail="Project not found")

    return ProjectResponse(
        id=project["id"], name=project["name"],
        description=project.get("description", ""),
        status=project.get("status", "active"),
        owner_id=project["owner_id"],
    )


@router.put("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: str,
    request: ProjectUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db_backend()
    project = await db.get_project(project_id)
    if not project or project.get("owner_id") != current_user["id"]:
        raise HTTPException(status_code=404, detail="Project not found")

    updates = {}
    if request.name is not None:
        updates["name"] = request.name
    if request.description is not None:
        updates["description"] = request.description

    if updates:
        project = await db.update_project(project_id, updates)

    return ProjectResponse(
        id=project["id"], name=project["name"],
        description=project.get("description", ""),
        status=project.get("status", "active"),
        owner_id=project["owner_id"],
    )


@router.delete("/{project_id}")
async def delete_project(
    project_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db_backend()
    project = await db.get_project(project_id)
    if not project or project.get("owner_id") != current_user["id"]:
        raise HTTPException(status_code=404, detail="Project not found")

    await db.delete_project(project_id)
    return {"message": f"Project '{project.get('name')}' deleted."}
