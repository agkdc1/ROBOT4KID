"""Admin endpoints for user management."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from planning_server.app.database import get_db, User
from planning_server.app.auth.dependencies import get_admin_user

router = APIRouter(prefix="/admin", tags=["admin"])


class UserResponse(BaseModel):
    id: int
    username: str
    role: str
    status: str


@router.get("/users/pending", response_model=list[UserResponse])
async def list_pending_users(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.status == "pending"))
    users = result.scalars().all()
    return [UserResponse(id=u.id, username=u.username, role=u.role, status=u.status) for u in users]


@router.post("/users/{user_id}/approve", response_model=UserResponse)
async def approve_user(
    user_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.status = "approved"
    await db.commit()
    await db.refresh(user)
    return UserResponse(id=user.id, username=user.username, role=user.role, status=user.status)


@router.post("/users/{user_id}/reject", response_model=UserResponse)
async def reject_user(
    user_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.status = "rejected"
    await db.commit()
    await db.refresh(user)
    return UserResponse(id=user.id, username=user.username, role=user.role, status=user.status)
