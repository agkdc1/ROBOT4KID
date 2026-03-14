"""Async bridge between the FastAPI server and the Webots TCP controllers.

Provides two communication channels:
  - **Tank command channel** (port 10200): sends binary TankCommand packets to
    the tank controller running inside Webots.
  - **Supervisor telemetry channel** (port 10201): receives newline-delimited
    JSON telemetry from the supervisor controller and exposes it as an async
    generator.

Both channels include automatic reconnection logic suitable for use behind
FastAPI WebSocket endpoints.
"""

from __future__ import annotations

import asyncio
import json
import logging
import math
import struct
from typing import Any, AsyncGenerator, Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Protocol constants (mirror embedded/lib/shared/protocol.h)
# ---------------------------------------------------------------------------
PACKET_HEADER = 0xAA

CMD_MOVE = 0x01
CMD_TURRET = 0x02
CMD_FIRE = 0x03
CMD_CAMERA = 0x04
CMD_STATUS = 0x05
CMD_HEARTBEAT = 0x06

# TankCommand struct — 10 bytes, little-endian, packed
TANK_CMD_FMT = "<BBbbhbBBB"
TANK_CMD_SIZE = struct.calcsize(TANK_CMD_FMT)

# Supervisor ports
TANK_PORT = 10200
SUPERVISOR_PORT = 10201

# Reconnection settings
RECONNECT_DELAY_S = 1.0
MAX_RECONNECT_DELAY_S = 10.0


def _xor_checksum(data: bytes) -> int:
    cs = 0
    for b in data:
        cs ^= b
    return cs


def build_tank_command(
    cmd_type: int,
    left_speed: int = 0,
    right_speed: int = 0,
    turret_angle: int = 0,
    barrel_elev: int = 0,
    fire: int = 0,
    camera_mode: int = 0,
) -> bytes:
    """Build a TankCommand packet ready to send over TCP.

    Args:
        cmd_type: One of CMD_MOVE, CMD_TURRET, CMD_FIRE, etc.
        left_speed: -100..+100 (differential drive).
        right_speed: -100..+100.
        turret_angle: Degrees x10 (0..3600).
        barrel_elev: -10..+45 degrees.
        fire: 0 or 1.
        camera_mode: 0=driver, 1=gunner, 2=split.

    Returns:
        10-byte TankCommand packet with valid checksum.
    """
    left_speed = max(-100, min(100, int(left_speed)))
    right_speed = max(-100, min(100, int(right_speed)))
    turret_angle = max(0, min(3600, int(turret_angle)))
    barrel_elev = max(-10, min(45, int(barrel_elev)))
    fire = 1 if fire else 0
    camera_mode = max(0, min(2, int(camera_mode)))

    payload = struct.pack(
        "<BBbbhbBB",
        PACKET_HEADER,
        cmd_type,
        left_speed,
        right_speed,
        turret_angle,
        barrel_elev,
        fire,
        camera_mode,
    )
    cs = _xor_checksum(payload)
    return payload + struct.pack("B", cs)


class WebotsBridge:
    """Async bridge to the Webots simulation controllers."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        tank_port: int = TANK_PORT,
        supervisor_port: int = SUPERVISOR_PORT,
    ) -> None:
        self._host = host
        self._tank_port = tank_port
        self._supervisor_port = supervisor_port

        # Tank command channel
        self._tank_reader: Optional[asyncio.StreamReader] = None
        self._tank_writer: Optional[asyncio.StreamWriter] = None

        # Supervisor telemetry channel
        self._sup_reader: Optional[asyncio.StreamReader] = None
        self._sup_writer: Optional[asyncio.StreamWriter] = None

        self._connected_tank = False
        self._connected_supervisor = False

    # ------------------------------------------------------------------
    # Connection management
    # ------------------------------------------------------------------

    async def connect_tank(self) -> bool:
        """Connect to the tank controller TCP socket."""
        if self._connected_tank:
            return True
        try:
            self._tank_reader, self._tank_writer = await asyncio.open_connection(
                self._host, self._tank_port,
            )
            self._connected_tank = True
            logger.info("Connected to tank controller at %s:%d", self._host, self._tank_port)
            return True
        except (ConnectionRefusedError, OSError) as exc:
            logger.debug("Tank controller not available: %s", exc)
            return False

    async def connect_supervisor(self) -> bool:
        """Connect to the supervisor controller TCP socket."""
        if self._connected_supervisor:
            return True
        try:
            self._sup_reader, self._sup_writer = await asyncio.open_connection(
                self._host, self._supervisor_port,
            )
            self._connected_supervisor = True
            logger.info("Connected to supervisor at %s:%d", self._host, self._supervisor_port)
            return True
        except (ConnectionRefusedError, OSError) as exc:
            logger.debug("Supervisor not available: %s", exc)
            return False

    async def disconnect(self) -> None:
        """Close all connections."""
        for writer, label in [
            (self._tank_writer, "tank"),
            (self._sup_writer, "supervisor"),
        ]:
            if writer is not None:
                try:
                    writer.close()
                    await writer.wait_closed()
                except OSError:
                    pass
                logger.debug("Disconnected from %s controller", label)
        self._tank_writer = None
        self._tank_reader = None
        self._sup_writer = None
        self._sup_reader = None
        self._connected_tank = False
        self._connected_supervisor = False

    # ------------------------------------------------------------------
    # Tank commands
    # ------------------------------------------------------------------

    async def send_command(
        self,
        cmd_type: int,
        *,
        left_speed: int = 0,
        right_speed: int = 0,
        turret_angle: int = 0,
        barrel_elev: int = 0,
        fire: int = 0,
        camera_mode: int = 0,
    ) -> bool:
        """Build and send a TankCommand to the tank controller.

        Returns True on success, False if the connection is down.
        """
        if not self._connected_tank:
            if not await self.connect_tank():
                return False

        packet = build_tank_command(
            cmd_type,
            left_speed=left_speed,
            right_speed=right_speed,
            turret_angle=turret_angle,
            barrel_elev=barrel_elev,
            fire=fire,
            camera_mode=camera_mode,
        )

        try:
            assert self._tank_writer is not None
            self._tank_writer.write(packet)
            await self._tank_writer.drain()
            return True
        except (ConnectionResetError, BrokenPipeError, OSError) as exc:
            logger.warning("Tank command send failed: %s", exc)
            self._connected_tank = False
            self._tank_writer = None
            self._tank_reader = None
            return False

    async def send_raw_command(self, packet: bytes) -> bool:
        """Send a pre-built binary TankCommand packet."""
        if not self._connected_tank:
            if not await self.connect_tank():
                return False
        try:
            assert self._tank_writer is not None
            self._tank_writer.write(packet)
            await self._tank_writer.drain()
            return True
        except (ConnectionResetError, BrokenPipeError, OSError) as exc:
            logger.warning("Tank raw send failed: %s", exc)
            self._connected_tank = False
            self._tank_writer = None
            self._tank_reader = None
            return False

    # ------------------------------------------------------------------
    # Supervisor commands
    # ------------------------------------------------------------------

    async def send_supervisor_command(self, cmd: dict[str, Any]) -> bool:
        """Send a JSON command to the supervisor controller."""
        if not self._connected_supervisor:
            if not await self.connect_supervisor():
                return False

        line = json.dumps(cmd, separators=(",", ":")) + "\n"
        try:
            assert self._sup_writer is not None
            self._sup_writer.write(line.encode("utf-8"))
            await self._sup_writer.drain()
            return True
        except (ConnectionResetError, BrokenPipeError, OSError) as exc:
            logger.warning("Supervisor command send failed: %s", exc)
            self._connected_supervisor = False
            self._sup_writer = None
            self._sup_reader = None
            return False

    # ------------------------------------------------------------------
    # Telemetry streaming
    # ------------------------------------------------------------------

    async def stream_telemetry(
        self,
        *,
        reconnect: bool = True,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Yield parsed JSON telemetry dicts from the supervisor.

        This is an async generator intended for use in a FastAPI WebSocket
        handler or similar consumer.

        Args:
            reconnect: If True, automatically reconnect on connection loss.
        """
        delay = RECONNECT_DELAY_S

        while True:
            if not self._connected_supervisor:
                connected = await self.connect_supervisor()
                if not connected:
                    if not reconnect:
                        return
                    logger.debug("Supervisor not ready — retrying in %.1fs", delay)
                    await asyncio.sleep(delay)
                    delay = min(delay * 1.5, MAX_RECONNECT_DELAY_S)
                    continue
                delay = RECONNECT_DELAY_S  # reset on success

            try:
                assert self._sup_reader is not None
                raw_line = await self._sup_reader.readline()
                if not raw_line:
                    logger.info("Supervisor stream ended")
                    self._connected_supervisor = False
                    self._sup_reader = None
                    self._sup_writer = None
                    if not reconnect:
                        return
                    continue

                text = raw_line.decode("utf-8", errors="replace").strip()
                if not text:
                    continue

                try:
                    data = json.loads(text)
                    yield data
                except json.JSONDecodeError:
                    logger.warning("Bad telemetry JSON: %s", text[:200])

            except (ConnectionResetError, BrokenPipeError, OSError) as exc:
                logger.warning("Telemetry stream error: %s", exc)
                self._connected_supervisor = False
                self._sup_reader = None
                self._sup_writer = None
                if not reconnect:
                    return

            except asyncio.CancelledError:
                return

    # ------------------------------------------------------------------
    # Context manager
    # ------------------------------------------------------------------

    async def __aenter__(self) -> "WebotsBridge":
        await self.connect_tank()
        await self.connect_supervisor()
        return self

    async def __aexit__(self, *exc: object) -> None:
        await self.disconnect()


# Module-level singleton
_default_bridge: Optional[WebotsBridge] = None


def get_bridge() -> WebotsBridge:
    """Return (and lazily create) the module-level WebotsBridge."""
    global _default_bridge
    if _default_bridge is None:
        _default_bridge = WebotsBridge()
    return _default_bridge
