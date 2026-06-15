"""
services/auth_service.py — Password hashing and JWT token logic.

Security decisions:
  - bcrypt via passlib — industry-standard adaptive hashing; slow by design to
    resist brute-force attacks. bcrypt.rounds defaults to 12.
  - HS256 JWT signed with a per-installation secret key stored in .env.
    The token payload carries: sub (username), user_id, role, exp (expiry).
  - Tokens are NOT stored server-side (stateless). To invalidate a specific
    token before expiry, add a token blocklist (Redis) in a future iteration.
"""
from __future__ import annotations

import logging
import warnings
from datetime import datetime, timedelta, timezone
from typing import Any

# Suppress the harmless passlib/bcrypt version-detection warning.
# passlib 1.7.4 looks for bcrypt.__about__.__version__ which bcrypt 4.x removed.
# The library still works correctly — this is just a noisy false-alarm warning.
warnings.filterwarnings("ignore", message=".*error reading bcrypt version.*")

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.user import User, UserRole

logger = logging.getLogger(__name__)
settings = get_settings()

# ── Password hashing ───────────────────────────────────────────────────────────
_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    """Return the bcrypt hash of a plaintext password.
    
    bcrypt has a hard limit of 72 bytes. Passwords longer than this are
    silently truncated by the C library, which can cause verify() to return
    True for different strings. We truncate explicitly so behaviour is
    predictable and consistent across bcrypt versions.
    """
    return _pwd_context.hash(plain[:72])


def verify_password(plain: str, hashed: str) -> bool:
    """Return True if `plain` matches the stored bcrypt hash.
    
    Truncate to 72 bytes to match the behaviour of hash_password().
    """
    return _pwd_context.verify(plain[:72], hashed)


# ── JWT ────────────────────────────────────────────────────────────────────────

def create_access_token(data: dict[str, Any]) -> tuple[str, int]:
    """
    Encode a JWT access token.

    Returns:
        (encoded_token, expires_in_seconds)
    """
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    payload = {**data, "exp": expire}
    token = jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )
    return token, settings.access_token_expire_minutes * 60


def decode_token(token: str) -> dict[str, Any]:
    """
    Decode and validate a JWT token.

    Raises:
        JWTError: if the token is invalid or expired.
    """
    return jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[settings.jwt_algorithm],
    )


# ── User operations ───────────────────────────────────────────────────────────

def get_user_by_identifier(identifier: str, db: Session) -> User | None:
    """Look up a user by username OR email (case-insensitive)."""
    return (
        db.query(User)
        .filter(
            or_(
                User.username.ilike(identifier),
                User.email.ilike(identifier),
            )
        )
        .first()
    )


def authenticate_user(identifier: str, password: str, db: Session) -> User | None:
    """
    Validate credentials.

    Returns the User on success, None on failure.
    Also updates last_login_at on success.
    """
    user = get_user_by_identifier(identifier, db)
    if not user:
        return None
    if not user.is_active:
        return None
    if not verify_password(password, user.hashed_password):
        return None

    # Record successful login time
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()
    return user


def create_user(
    username: str,
    email: str,
    password: str,
    role: UserRole = UserRole.analyst,
    db: Session = None,  # type: ignore[assignment]
) -> User:
    """Create and persist a new user with a hashed password."""
    user = User(
        username=username,
        email=email,
        hashed_password=hash_password(password),
        role=role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def seed_admin_user(db: Session) -> None:
    """
    Called at startup. Creates the default admin account if no users exist yet.
    Uses credentials from settings (override via .env).
    """
    if db.query(User).count() > 0:
        return  # Already seeded

    logger.info("No users found — seeding default admin account.")
    create_user(
        username=settings.admin_username,
        email=settings.admin_email,
        password=settings.admin_password,
        role=UserRole.admin,
        db=db,
    )
    logger.info("Default admin created: username=%r", settings.admin_username)
