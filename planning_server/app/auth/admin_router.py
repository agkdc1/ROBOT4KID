"""Admin endpoints for user management."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from shared.db_backend import get_db_backend
from planning_server.app.auth.dependencies import get_admin_user

router = APIRouter(prefix="/admin", tags=["admin"])


class UserResponse(BaseModel):
    id: str
    username: str
    role: str
    status: str


@router.get("/users/pending", response_model=list[UserResponse])
async def list_pending_users(admin: dict = Depends(get_admin_user)):
    db = get_db_backend()
    users = await db.list_users(status="pending")
    return [UserResponse(id=u["id"], username=u["username"],
                         role=u["role"], status=u["status"]) for u in users]


@router.post("/users/{user_id}/approve", response_model=UserResponse)
async def approve_user(user_id: str, admin: dict = Depends(get_admin_user)):
    db = get_db_backend()
    user = await db.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    updated = await db.update_user(user_id, {"status": "approved"})
    return UserResponse(id=updated["id"], username=updated["username"],
                        role=updated["role"], status=updated["status"])


@router.post("/users/{user_id}/reject", response_model=UserResponse)
async def reject_user(user_id: str, admin: dict = Depends(get_admin_user)):
    db = get_db_backend()
    user = await db.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    updated = await db.update_user(user_id, {"status": "rejected"})
    return UserResponse(id=updated["id"], username=updated["username"],
                        role=updated["role"], status=updated["status"])
