"""Planning Server — FastAPI entrypoint."""

import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from planning_server.app import config
from planning_server.app.auth.dependencies import hash_password
from planning_server.app.auth.router import router as auth_router
from planning_server.app.auth.admin_router import router as admin_router
from planning_server.app.projects.router import router as projects_router
from planning_server.app.pipeline.router import router as pipeline_router
from planning_server.app.fcs.router import router as fcs_router
from planning_server.app.web_ui import router as web_router
from planning_server.app.dashboard.router import router as dashboard_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown logic."""
    from shared.db_backend import init_db_backend, get_db_backend

    await init_db_backend()

    # Create default admin user if not exists
    db = get_db_backend()
    existing = await db.get_user_by_username(config.ADMIN_USERNAME)
    if not existing:
        await db.create_user(
            username=config.ADMIN_USERNAME,
            hashed_password=hash_password(config.ADMIN_PASSWORD),
            role="admin",
            status="approved",
        )

    yield


app = FastAPI(
    title="NL2Bot Planning Server",
    description="Claude-powered planning server for NL-to-robotics pipeline.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Gate: in cloud mode, reject requests not coming through Cloudflare Worker
import os
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

_WORKER_SECRET = os.getenv("CF_WORKER_SECRET", "")

class WorkerGateMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if _WORKER_SECRET and request.url.path != "/api/v1/health":
            if request.headers.get("X-Worker-Secret") != _WORKER_SECRET:
                return JSONResponse({"detail": "Forbidden"}, status_code=403)
        return await call_next(request)

if os.getenv("ENVIRONMENT") == "cloud" and _WORKER_SECRET:
    app.add_middleware(WorkerGateMiddleware)

# Health check — defined early, before any mounts
@app.get("/api/v1/health")
async def health_check():
    return {"status": "ok", "service": "planning_server", "version": "0.1.0"}

# API routes
app.include_router(auth_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(projects_router, prefix="/api/v1")
app.include_router(pipeline_router, prefix="/api/v1")
app.include_router(fcs_router)
app.include_router(dashboard_router, prefix="/api/v1")

# HTMX Web UI (legacy, at /legacy/)
app.include_router(web_router, prefix="/legacy")

# Static files (HTMX web UI assets)
static_dir = Path(__file__).parent.parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

# React dashboard SPA — MUST be last (catches all unmatched routes)
# html=True serves index.html for SPA client-side routing
dashboard_dir = Path(__file__).parent.parent / "dashboard_dist"
if dashboard_dir.exists():
    app.mount("/", StaticFiles(directory=str(dashboard_dir), html=True), name="dashboard")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config.HOST, port=config.PORT)
