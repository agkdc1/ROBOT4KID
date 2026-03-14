"""Webots simulation API endpoints.

Provides REST and WebSocket endpoints for controlling Webots simulations
from the planning server or any other client.

Routes:
    POST   /api/v1/webots/start     — start simulation for a job
    POST   /api/v1/webots/stop      — stop current simulation
    GET    /api/v1/webots/status     — get simulation status
    WS     /api/v1/webots/{job_id}/ws — live telemetry stream
    POST   /api/v1/webots/command   — send command to tank
"""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field

from simulation_server.app import config
from simulation_server.app.simulator.webots_manager import get_manager
from simulation_server.app.simulator.webots_bridge import (
    get_bridge,
    CMD_MOVE,
    CMD_TURRET,
    CMD_FIRE,
    CMD_CAMERA,
    CMD_STATUS,
    CMD_HEARTBEAT,
)
from simulation_server.app.simulator.proto_converter import convert_urdf_to_proto

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webots", tags=["webots"])

# Default world file location (relative to project root)
_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_DEFAULT_WORLD = _PROJECT_ROOT / "simulation" / "worlds" / "flat_ground.wbt"


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------

class StartRequest(BaseModel):
    job_id: str = Field(description="Simulation job ID")
    world_path: Optional[str] = Field(
        default=None,
        description="Custom world file path. Defaults to flat_ground.wbt.",
    )
    convert_urdf: bool = Field(
        default=False,
        description="If True, convert the job's URDF to a PROTO before starting.",
    )


class StopRequest(BaseModel):
    force: bool = Field(default=False, description="Force kill the Webots process")


class CommandRequest(BaseModel):
    cmd_type: str = Field(
        description="Command type: move, turret, fire, camera, status, heartbeat",
    )
    left_speed: int = Field(default=0, ge=-100, le=100)
    right_speed: int = Field(default=0, ge=-100, le=100)
    turret_angle: int = Field(default=0, ge=0, le=3600, description="Degrees x10")
    barrel_elevation: int = Field(default=0, ge=-10, le=45)
    fire: int = Field(default=0, ge=0, le=1)
    camera_mode: int = Field(default=0, ge=0, le=2)


class StatusResponse(BaseModel):
    running: bool
    pid: Optional[int] = None
    world_path: Optional[str] = None
    tank_connected: bool = False
    supervisor_connected: bool = False


# ---------------------------------------------------------------------------
# Command type mapping
# ---------------------------------------------------------------------------

_CMD_TYPE_MAP: dict[str, int] = {
    "move": CMD_MOVE,
    "turret": CMD_TURRET,
    "fire": CMD_FIRE,
    "camera": CMD_CAMERA,
    "status": CMD_STATUS,
    "heartbeat": CMD_HEARTBEAT,
}


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/start")
async def start_simulation(req: StartRequest) -> dict:
    """Start a Webots simulation.

    If *convert_urdf* is True and the job directory contains a URDF file,
    it will be converted to a .proto before launching Webots.
    """
    manager = get_manager()

    # Determine world path
    if req.world_path:
        world = Path(req.world_path)
    else:
        world = _DEFAULT_WORLD

    if not world.exists():
        raise HTTPException(status_code=404, detail=f"World file not found: {world}")

    # Optionally convert URDF → PROTO
    if req.convert_urdf:
        job_dir = config.JOBS_DIR / req.job_id
        urdf_candidates = list(job_dir.glob("*.urdf"))
        if urdf_candidates:
            urdf_path = urdf_candidates[0]
            stl_dir = job_dir / "stl"
            proto_path = job_dir / f"{urdf_path.stem}.proto"
            try:
                convert_urdf_to_proto(urdf_path, stl_dir, proto_path)
                logger.info("Converted URDF to PROTO: %s", proto_path)
            except Exception as exc:
                logger.error("URDF→PROTO conversion failed: %s", exc)
                raise HTTPException(
                    status_code=500,
                    detail=f"PROTO conversion failed: {exc}",
                )
        else:
            logger.warning("No URDF file found in job %s, skipping conversion", req.job_id)

    try:
        await manager.start_simulation(world)
    except Exception as exc:
        logger.error("Failed to start Webots: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to start Webots: {exc}")

    return {
        "status": "started",
        "job_id": req.job_id,
        "pid": manager.pid,
        "world": str(world),
    }


@router.post("/stop")
async def stop_simulation(req: StopRequest | None = None) -> dict:
    """Stop the running Webots simulation."""
    manager = get_manager()

    if not manager.is_running():
        return {"status": "not_running"}

    bridge = get_bridge()
    await bridge.disconnect()

    timeout = 5.0 if (req and req.force) else 10.0
    await manager.stop_simulation(timeout=timeout)

    return {"status": "stopped"}


@router.get("/status", response_model=StatusResponse)
async def simulation_status() -> StatusResponse:
    """Return current Webots simulation status."""
    manager = get_manager()
    bridge = get_bridge()

    return StatusResponse(
        running=manager.is_running(),
        pid=manager.pid,
        world_path=str(manager.world_path) if manager.world_path else None,
        tank_connected=bridge._connected_tank,
        supervisor_connected=bridge._connected_supervisor,
    )


@router.post("/command")
async def send_command(req: CommandRequest) -> dict:
    """Send a command to the tank controller."""
    cmd_int = _CMD_TYPE_MAP.get(req.cmd_type.lower())
    if cmd_int is None:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown command type '{req.cmd_type}'. "
                   f"Valid types: {', '.join(_CMD_TYPE_MAP.keys())}",
        )

    bridge = get_bridge()
    success = await bridge.send_command(
        cmd_int,
        left_speed=req.left_speed,
        right_speed=req.right_speed,
        turret_angle=req.turret_angle,
        barrel_elev=req.barrel_elevation,
        fire=req.fire,
        camera_mode=req.camera_mode,
    )

    if not success:
        raise HTTPException(
            status_code=503,
            detail="Could not send command — tank controller not connected",
        )

    return {"status": "sent", "cmd_type": req.cmd_type}


@router.websocket("/{job_id}/ws")
async def telemetry_websocket(websocket: WebSocket, job_id: str) -> None:
    """WebSocket endpoint for live telemetry streaming.

    Clients connect to receive real-time JSON telemetry from the
    supervisor controller. They can also send JSON commands that are
    forwarded to the supervisor.
    """
    await websocket.accept()
    logger.info("WebSocket client connected for job %s", job_id)

    bridge = get_bridge()

    # Start receiving telemetry in background
    async def _stream_to_client() -> None:
        try:
            async for telemetry in bridge.stream_telemetry(reconnect=True):
                telemetry["job_id"] = job_id
                await websocket.send_json(telemetry)
        except WebSocketDisconnect:
            pass
        except asyncio.CancelledError:
            pass
        except Exception as exc:
            logger.error("Telemetry stream error: %s", exc)

    stream_task = asyncio.create_task(_stream_to_client())

    try:
        # Listen for incoming commands from the WebSocket client
        while True:
            data = await websocket.receive_json()
            cmd = data.get("cmd")

            if cmd in ("start", "stop", "reset", "get_state", "set_telemetry_rate", "set_position"):
                await bridge.send_supervisor_command(data)
            elif cmd == "tank_command":
                # Forward as binary tank command
                cmd_int = _CMD_TYPE_MAP.get(data.get("type", ""), CMD_MOVE)
                await bridge.send_command(
                    cmd_int,
                    left_speed=data.get("left_speed", 0),
                    right_speed=data.get("right_speed", 0),
                    turret_angle=data.get("turret_angle", 0),
                    barrel_elev=data.get("barrel_elevation", 0),
                    fire=data.get("fire", 0),
                    camera_mode=data.get("camera_mode", 0),
                )
            else:
                await websocket.send_json({"error": f"Unknown command: {cmd}"})

    except WebSocketDisconnect:
        logger.info("WebSocket client disconnected (job %s)", job_id)
    except Exception as exc:
        logger.error("WebSocket error: %s", exc)
    finally:
        stream_task.cancel()
        try:
            await stream_task
        except asyncio.CancelledError:
            pass
