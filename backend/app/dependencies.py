"""
dependencies.py — Reusable FastAPI dependencies for authentication.

Usage in any router:
    @router.get("/protected")
    def protected(current_user: User = Depends(get_current_user)):
        ...

    # Require admin role:
    @router.delete("/something")
    def delete_it(current_user: User = Depends(require_admin)):
        ...
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User, UserRole
from app.services.auth_service import decode_token

# HTTPBearer extracts the token from "Authorization: Bearer <token>" headers.
_bearer = HTTPBearer(auto_error=True)

_CREDENTIALS_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """
    Decode the JWT from the Authorization header and return the associated User.
    Raises 401 if the token is invalid, expired, or the user no longer exists.
    """
    try:
        payload = decode_token(credentials.credentials)
        user_id: int | None = payload.get("user_id")
        if user_id is None:
            raise _CREDENTIALS_EXCEPTION
    except JWTError:
        raise _CREDENTIALS_EXCEPTION

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise _CREDENTIALS_EXCEPTION
    return user


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Like get_current_user but also enforces the 'admin' role."""
    if current_user.role != UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin role required for this operation",
        )
    return current_user
