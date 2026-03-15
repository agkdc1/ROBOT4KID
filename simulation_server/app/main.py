"""Simulation Server — FastAPI entrypoint."""

import sys
from pathlib import Path

# Load .env before anything reads os.getenv
from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

# Add project root to path so shared schemas are importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from fastapi import Depends, FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from simulation_server.app import config
from simulation_server.app.auth import require_api_key
from simulation_server.app.renderer.router import router as renderer_router
from simulation_server.app.assembler.router import router as assembler_router
from simulation_server.app.analyzer.router import router as analyzer_router
from simulation_server.app.viewer.router import router as viewer_router
from simulation_server.app.jobs_router import router as jobs_router
from simulation_server.app.simulator.router import router as webots_router

app = FastAPI(
    title="NL2Bot Simulation Server",
    description="Standalone simulation server: SCAD rendering, URDF assembly, physics simulation, printability analysis.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers (all require API key auth)
app.include_router(jobs_router, prefix="/api/v1", tags=["jobs"])  # Read endpoints public (viewer needs STL access); writes protected per-route
app.include_router(renderer_router, prefix="/api/v1", tags=["renderer"], dependencies=[Depends(require_api_key)])
app.include_router(assembler_router, prefix="/api/v1", tags=["assembler"], dependencies=[Depends(require_api_key)])
app.include_router(analyzer_router, prefix="/api/v1", tags=["analyzer"], dependencies=[Depends(require_api_key)])
app.include_router(viewer_router, prefix="/api/v1/viewer", tags=["viewer"])  # No auth — browser-accessible
app.include_router(webots_router, prefix="/api/v1", tags=["webots"], dependencies=[Depends(require_api_key)])

# Serve viewer static files
viewer_static = Path(__file__).parent / "viewer" / "static"
if viewer_static.exists():
    app.mount("/viewer-static", StaticFiles(directory=str(viewer_static)), name="viewer-static")


@app.get("/api/v1/health")
async def health_check():
    return {"status": "ok", "service": "simulation_server", "version": "0.1.0"}


@app.get("/api/v1/capabilities")
async def capabilities():
    return {
        "render": True,
        "assemble": True,
        "physics": True,  # Webots simulation integrated
        "printability": True,
        "viewer": True,
        "ballistics_training": False,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config.HOST, port=config.PORT)
