"""Authentication endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from planning_server.app.database import get_db, User
from planning_server.app.auth.dependencies import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    get_current_user,
    get_admin_user,
)

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=6, max_length=100)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: int
    username: str
    role: str
    status: str


@router.post("/register", response_model=UserResponse, status_code=201)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check if username already exists
    result = await db.execute(select(User).where(User.username == request.username))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Username already registered")

    user = User(
        username=request.username,
        hashed_password=hash_password(request.password),
        role="user",
        status="pending",
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return UserResponse(id=user.id, username=user.username, role=user.role, status=user.status)


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.username == form_data.username))
    user = result.scalar_one_or_none()

    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    if user.status != "approved":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account not approved. Current status: {user.status}",
        )

    return TokenResponse(
        access_token=create_access_token(data={"sub": user.username}),
        refresh_token=create_refresh_token(data={"sub": user.username}),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        username=current_user.username,
        role=current_user.role,
        status=current_user.status,
    )
