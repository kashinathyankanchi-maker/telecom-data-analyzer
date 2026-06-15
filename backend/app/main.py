"""
main.py — FastAPI Application Entry Point.

Registers all routers, configures CORS, and sets up lifespan events
(database table creation + admin user seed on startup).

Auth architecture:
  - /api/v1/auth/* — public (login, token refresh)
  - /api/v1/*      — protected; requires valid Bearer JWT
  
  Protection is applied at the router level (dependencies=[Depends(get_current_user)])
  rather than middleware level — this gives finer-grained control and
  plays nicely with FastAPI's OpenAPI documentation.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import engine, SessionLocal
from app.models import CDR, SDR, TDR          # noqa: F401 — table registration
from app.models.user import User               # noqa: F401 — table registration
from app.database import Base
from app.dependencies import get_current_user
from app.services.auth_service import seed_admin_user

# Routers
from app.routers.auth   import router as auth_router
from app.routers.ingest import router as ingest_router
from app.routers.search import router as search_router
from app.routers.graph  import router as graph_router
from app.routers.geo    import router as geo_router

settings = get_settings()

API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup:
      1. Create all DB tables (safe no-op if they already exist).
      2. Seed the default admin user if the users table is empty.
    """
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        seed_admin_user(db)
    finally:
        db.close()

    yield
    # Shutdown: nothing to clean up — SQLAlchemy pool handles connections.


app = FastAPI(
    title="Telecom Data Analyzer API",
    description=(
        "Secure backend for ingesting and analyzing CDR, SDR, and TDR records.\n\n"
        "**Authentication**: All `/api/v1/` endpoints (except `/auth/login`) "
        "require a valid `Authorization: Bearer <token>` header.\n\n"
        "Use `POST /api/v1/auth/login` to obtain your token."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Auth router (PUBLIC — no auth dependency) ─────────────────────────────────
app.include_router(auth_router, prefix=API_PREFIX)

# ── Protected routers (ALL require a valid JWT) ───────────────────────────────
_auth_dep = [Depends(get_current_user)]

app.include_router(ingest_router, prefix=API_PREFIX, dependencies=_auth_dep)
app.include_router(search_router, prefix=API_PREFIX, dependencies=_auth_dep)
app.include_router(graph_router,  prefix=API_PREFIX, dependencies=_auth_dep)
app.include_router(geo_router,    prefix=API_PREFIX, dependencies=_auth_dep)


# ── Health check (PUBLIC) ─────────────────────────────────────────────────────
@app.get("/api/v1/health", tags=["System"], summary="Health check (public)")
def health_check():
    """Public health check — does not require authentication."""
    return {"status": "ok", "version": "1.0.0"}
