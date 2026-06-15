"""
routers/auth.py — Authentication Endpoints.

POST /api/v1/auth/register  → Create a new user (admin only in production)
POST /api/v1/auth/login     → Validate credentials, return JWT
GET  /api/v1/auth/me        → Return current authenticated user profile
PUT  /api/v1/auth/me        → Update own password
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.database import get_db
from app.dependencies import get_current_user, require_admin
from app.models.user import User
from app.schemas.auth import TokenResponse, UserCreate, UserLogin, UserRead
from app.services.auth_service import (
    authenticate_user,
    create_access_token,
    create_user,
    get_user_by_identifier,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── POST /auth/login ──────────────────────────────────────────────────────────
@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Obtain a JWT access token",
)
def login(body: UserLogin, db: Session = Depends(get_db)):
    """
    Authenticate with **username or email** + **password**.

    On success returns:
    - `access_token` — Bearer token to include in all subsequent requests.
    - `expires_in`   — Seconds until the token expires.
    - `user`         — The authenticated user's profile.
    """
    user = authenticate_user(body.identifier, body.password, db)
    if not user:
        # Use a generic message to avoid disclosing which field was wrong
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please check your username/email and password.",
        )

    token, expires_in = create_access_token({
        "sub":     user.username,
        "user_id": user.id,
        "role":    user.role.value,
    })

    return TokenResponse(
        access_token=token,
        expires_in=expires_in,
        user=UserRead.model_validate(user),
    )


# ── POST /auth/register ───────────────────────────────────────────────────────
@router.post(
    "/register",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user (admin only)",
)
def register(
    body: UserCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),   # Only admins can create new users
):
    """
    Create a new application user.

    > **Requires admin role.** Ordinary users cannot self-register —
      an administrator must create accounts via this endpoint.
    """
    # Check for duplicate username / email before attempting insert
    if get_user_by_identifier(body.username, db):
        raise HTTPException(status_code=409, detail="Username already taken.")
    if get_user_by_identifier(body.email, db):
        raise HTTPException(status_code=409, detail="Email already registered.")

    try:
        user = create_user(
            username=body.username,
            email=body.email,
            password=body.password,
            role=body.role,
            db=db,
        )
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Username or email already exists.")

    return UserRead.model_validate(user)


# ── GET /auth/me ──────────────────────────────────────────────────────────────
@router.get(
    "/me",
    response_model=UserRead,
    summary="Get the current user's profile",
)
def get_me(current_user: User = Depends(get_current_user)):
    """Return the authenticated user's profile. Used by Flutter on app launch
    to validate a stored token and restore session state."""
    return UserRead.model_validate(current_user)


# ── PUT /auth/me/password ─────────────────────────────────────────────────────
from pydantic import BaseModel, Field

class PasswordChangeBody(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password:     str = Field(..., min_length=8)

@router.put(
    "/me/password",
    summary="Change own password",
    status_code=status.HTTP_204_NO_CONTENT,
)
def change_password(
    body: PasswordChangeBody,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Allow a logged-in user to change their own password."""
    if not verify_password(body.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")

    current_user.hashed_password = hash_password(body.new_password)
    db.commit()
