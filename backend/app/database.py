"""
database.py — SQLAlchemy engine, session factory, and declarative base.
All models import Base from here; all route handlers use get_db() as a dependency.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.config import get_settings

settings = get_settings()

# ── Engine ────────────────────────────────────────────────────────────────────
# pool_pre_ping=True recycles stale connections automatically.
engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    echo=(settings.app_env == "development"),  # SQL logging in dev only
)

# ── Session factory ────────────────────────────────────────────────────────────
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

# ── Declarative base ───────────────────────────────────────────────────────────
class Base(DeclarativeBase):
    """All ORM models must inherit from this class."""
    pass


# ── Dependency ─────────────────────────────────────────────────────────────────
def get_db():
    """
    FastAPI dependency that yields a database session and guarantees
    the session is closed after the request, even on exception.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
