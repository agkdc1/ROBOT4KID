"""Authentication endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, Field

from shared.db_backend import get_db_backend
from planning_server.app.auth.dependencies import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    get_current_user,
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
    id: str
    username: str
    role: str
    status: str


@router.post("/register", response_model=UserResponse, status_code=201)
async def register(request: RegisterRequest):
    db = get_db_backend()
    existing = await db.get_user_by_username(request.username)
    if existing:
        raise HTTPException(status_code=400, detail="Username already registered")

    user = await db.create_user(
        username=request.username,
        hashed_password=hash_password(request.password),
    )
    return UserResponse(id=user["id"], username=user["username"],
                        role=user["role"], status=user["status"])


@router.post("/login", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    db = get_db_backend()
    user = await db.get_user_by_username(form_data.username)

    if not user or not verify_password(form_data.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    if user.get("status") != "approved":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account not approved. Current status: {user.get('status')}",
        )

    return TokenResponse(
        access_token=create_access_token(data={"sub": user["username"]}),
        refresh_token=create_refresh_token(data={"sub": user["username"]}),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    return UserResponse(
        id=current_user["id"],
        username=current_user["username"],
        role=current_user["role"],
        status=current_user["status"],
    )
