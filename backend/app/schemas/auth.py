"""
schemas/auth.py — Pydantic schemas for authentication endpoints.
"""
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field
from app.models.user import UserRole


# ── Request schemas ────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    """Body for POST /auth/register"""
    username: str = Field(..., min_length=3, max_length=64, pattern=r"^[a-zA-Z0-9_.-]+$")
    email: EmailStr
    password: str = Field(
        ...,
        min_length=8,
        description="Must be at least 8 characters",
    )
    role: UserRole = UserRole.analyst


class UserLogin(BaseModel):
    """Body for POST /auth/login — accepts username OR email."""
    identifier: str = Field(..., description="Username or email address")
    password:   str = Field(..., min_length=1)


# ── Response schemas ───────────────────────────────────────────────────────────

class TokenResponse(BaseModel):
    """Returned by /auth/login on success."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int           # seconds until expiry
    user: "UserRead"


class UserRead(BaseModel):
    """Public user representation — never includes hashed_password."""
    id:           int
    username:     str
    email:        str
    role:         UserRole
    is_active:    bool
    created_at:   datetime
    last_login_at: datetime | None = None

    model_config = {"from_attributes": True}


# Forward ref resolution
TokenResponse.model_rebuild()
