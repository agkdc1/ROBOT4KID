"""Project CRUD endpoints."""

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from planning_server.app import config
from planning_server.app.database import get_db, User, Project
from planning_server.app.auth.dependencies import get_current_user

router = APIRouter(prefix="/projects", tags=["projects"])


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(default="")


class ProjectResponse(BaseModel):
    id: int
    name: str
    description: str
    status: str
    owner_id: int


class ProjectUpdate(BaseModel):
    name: str | None = None
    description: str | None = None


@router.get("", response_model=list[ProjectResponse])
async def list_projects(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Project).where(Project.owner_id == current_user.id)
    )
    projects = result.scalars().all()
    return [
        ProjectResponse(
            id=p.id, name=p.name, description=p.description,
            status=p.status, owner_id=p.owner_id,
        )
        for p in projects
    ]


@router.post("", response_model=ProjectResponse, status_code=201)
async def create_project(
    request: ProjectCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    project = Project(
        name=request.name,
        description=request.description,
        owner_id=current_user.id,
    )
    db.add(project)
    await db.commit()
    await db.refresh(project)

    # Create project directory
    project_dir = config.PROJECTS_DIR / str(project.id)
    for sub in ["conversations", "scad", "firmware", "flutter"]:
        (project_dir / sub).mkdir(parents=True, exist_ok=True)

    return ProjectResponse(
        id=project.id, name=project.name, description=project.description,
        status=project.status, owner_id=project.owner_id,
    )


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Project).where(Project.id == project_id, Project.owner_id == current_user.id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    return ProjectResponse(
        id=project.id, name=project.name, description=project.description,
        status=project.status, owner_id=project.owner_id,
    )


@router.put("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: int,
    request: ProjectUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Project).where(Project.id == project_id, Project.owner_id == current_user.id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if request.name is not None:
        project.name = request.name
    if request.description is not None:
        project.description = request.description

    await db.commit()
    await db.refresh(project)

    return ProjectResponse(
        id=project.id, name=project.name, description=project.description,
        status=project.status, owner_id=project.owner_id,
    )


@router.delete("/{project_id}")
async def delete_project(
    project_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Project).where(Project.id == project_id, Project.owner_id == current_user.id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    await db.delete(project)
    await db.commit()
    return {"message": f"Project '{project.name}' deleted."}
