"""Planning Server — FastAPI entrypoint."""

import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.templating import Jinja2Templates

from planning_server.app import config
from planning_server.app.database import init_db, async_session, User
from planning_server.app.auth.dependencies import hash_password
from planning_server.app.auth.router import router as auth_router
from planning_server.app.auth.admin_router import router as admin_router
from planning_server.app.projects.router import router as projects_router
from planning_server.app.pipeline.router import router as pipeline_router
from planning_server.app.fcs.router import router as fcs_router
from planning_server.app.web_ui import router as web_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown logic."""
    await init_db()

    # Create default admin user if not exists
    from sqlalchemy import select

    async with async_session() as db:
        result = await db.execute(select(User).where(User.username == config.ADMIN_USERNAME))
        if not result.scalar_one_or_none():
            admin = User(
                username=config.ADMIN_USERNAME,
                hashed_password=hash_password(config.ADMIN_PASSWORD),
                role="admin",
                status="approved",
            )
            db.add(admin)
            await db.commit()

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

# API routes
app.include_router(auth_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(projects_router, prefix="/api/v1")
app.include_router(pipeline_router, prefix="/api/v1")
app.include_router(fcs_router)

# Web UI
app.include_router(web_router)

# Static files
static_dir = Path(__file__).parent.parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/api/v1/health")
async def health_check():
    return {"status": "ok", "service": "planning_server", "version": "0.1.0"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config.HOST, port=config.PORT)
