"""
models/user.py — Application User model for authentication.

Stores hashed passwords — plaintext passwords are NEVER stored.
Role field supports future RBAC expansion (admin, analyst, viewer).
"""
import enum
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Enum, Integer
from app.database import Base


class UserRole(str, enum.Enum):
    admin   = "admin"
    analyst = "analyst"
    viewer  = "viewer"


class User(Base):
    """
    Application user. Authenticates via username/email + password.
    JWT tokens are issued on successful login.
    """
    __tablename__ = "users"

    id            = Column(Integer, primary_key=True, autoincrement=True)
    username      = Column(String(64), unique=True, nullable=False, index=True)
    email         = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)

    role          = Column(Enum(UserRole), nullable=False, default=UserRole.analyst)
    is_active     = Column(Boolean, nullable=False, default=True)

    # Audit fields
    created_at    = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)

    def __repr__(self) -> str:
        return f"<User id={self.id} username={self.username!r} role={self.role}>"
