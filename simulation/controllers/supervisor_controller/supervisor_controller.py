"""Supervisor controller for Webots — JSON command/telemetry interface.

Listens on TCP port 10201 for JSON commands and streams telemetry at a
configurable rate (default 30 Hz). This controller runs as a Webots
Supervisor, giving it full access to simulation state (get/set positions,
reset, etc.).

JSON command format (newline-delimited):
    {"cmd": "start"}                       — resume physics
    {"cmd": "stop"}                        — pause physics
    {"cmd": "reset"}                       — reset robot to origin
    {"cmd": "get_state"}                   — one-shot state response
    {"cmd": "set_telemetry_rate", "hz": N} — change streaming rate
    {"cmd": "set_position", "x": f, "y": f, "z": f}

Telemetry output (newline-delimited JSON):
    {
        "time": float,
        "position": [x, y, z],
        "rotation": [rx, ry, rz],
        "speed": float,
        "turret_angle": float,
        "barrel_angle": float,
        "tof_distance": float,
        "imu": {"roll": f, "pitch": f, "yaw": f}
    }
"""

from __future__ import annotations

import json
import logging
import math
import select
import socket
import sys
import time
from typing import Any, Optional

# Webots supervisor API
try:
    from controller import Supervisor  # type: ignore[import-untyped]
except ImportError:
    Supervisor = None  # type: ignore[assignment,misc]

TCP_PORT = 10201
DEFAULT_TELEMETRY_HZ = 30

logging.basicConfig(
    level=logging.INFO,
    format="[supervisor] %(levelname)s %(message)s",
)
logger = logging.getLogger("supervisor_controller")


class SupervisorController:
    """Webots Supervisor with JSON-over-TCP command/telemetry interface."""

    def __init__(self) -> None:
        if Supervisor is None:
            raise RuntimeError("Must be run inside Webots (controller module not found)")

        self.supervisor = Supervisor()
        self.timestep: int = int(self.supervisor.getBasicTimeStep())

        # Get robot node
        self.robot_node = self.supervisor.getFromDef("TANK")
        if self.robot_node is None:
            logger.error("DEF TANK not found in world — supervisor will have limited functionality")

        # Sensor device references (read via supervisor if available)
        self._turret_sensor = self.supervisor.getDevice("turret_sensor")
        self._barrel_sensor = self.supervisor.getDevice("barrel_sensor")
        self._tof_sensor = self.supervisor.getDevice("tof_sensor")
        self._imu = self.supervisor.getDevice("imu")

        # Enable sensors
        for sensor in (self._turret_sensor, self._barrel_sensor, self._tof_sensor, self._imu):
            if sensor is not None:
                sensor.enable(self.timestep)

        # Telemetry config
        self._telemetry_hz: float = DEFAULT_TELEMETRY_HZ
        self._streaming: bool = True
        self._paused: bool = False

        # Previous position for speed calculation
        self._prev_position: Optional[list[float]] = None
        self._prev_time: float = 0.0

        # TCP
        self._server_sock: Optional[socket.socket] = None
        self._clients: list[socket.socket] = []
        self._recv_bufs: dict[int, str] = {}  # fd -> partial line buffer

        logger.info("Supervisor controller initialised (timestep=%d ms)", self.timestep)

    # ------------------------------------------------------------------
    # Networking
    # ------------------------------------------------------------------

    def _start_server(self) -> None:
        self._server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server_sock.bind(("0.0.0.0", TCP_PORT))
        self._server_sock.listen(4)
        self._server_sock.setblocking(False)
        logger.info("Supervisor TCP server listening on port %d", TCP_PORT)

    def _accept_clients(self) -> None:
        if self._server_sock is None:
            return
        readable, _, _ = select.select([self._server_sock], [], [], 0)
        if readable:
            conn, addr = self._server_sock.accept()
            conn.setblocking(False)
            self._clients.append(conn)
            self._recv_bufs[conn.fileno()] = ""
            logger.info("Supervisor client connected from %s", addr)

    def _read_commands(self) -> list[dict[str, Any]]:
        """Read newline-delimited JSON commands from all clients."""
        commands: list[dict[str, Any]] = []
        disconnected: list[socket.socket] = []

        for client in self._clients:
            try:
                readable, _, _ = select.select([client], [], [], 0)
                if not readable:
                    continue
                data = client.recv(4096)
                if not data:
                    disconnected.append(client)
                    continue
                fd = client.fileno()
                self._recv_bufs[fd] = self._recv_bufs.get(fd, "") + data.decode("utf-8", errors="replace")

                # Process complete lines
                while "\n" in self._recv_bufs[fd]:
                    line, self._recv_bufs[fd] = self._recv_bufs[fd].split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        cmd = json.loads(line)
                        commands.append(cmd)
                    except json.JSONDecodeError:
                        logger.warning("Invalid JSON from client: %s", line[:200])
            except (ConnectionResetError, OSError):
                disconnected.append(client)

        for client in disconnected:
            self._remove_client(client)

        return commands

    def _remove_client(self, client: socket.socket) -> None:
        fd = client.fileno()
        self._recv_bufs.pop(fd, None)
        try:
            client.close()
        except OSError:
            pass
        if client in self._clients:
            self._clients.remove(client)
        logger.info("Supervisor client disconnected")

    def _broadcast(self, msg: dict[str, Any]) -> None:
        """Send JSON message to all connected clients."""
        raw = json.dumps(msg, separators=(",", ":")) + "\n"
        encoded = raw.encode("utf-8")
        disconnected: list[socket.socket] = []
        for client in self._clients:
            try:
                client.sendall(encoded)
            except (BrokenPipeError, ConnectionResetError, OSError):
                disconnected.append(client)
        for client in disconnected:
            self._remove_client(client)

    # ------------------------------------------------------------------
    # Command handling
    # ------------------------------------------------------------------

    def _handle_command(self, cmd: dict[str, Any]) -> None:
        action = cmd.get("cmd", "")
        match action:
            case "start":
                self._paused = False
                self.supervisor.simulationSetMode(Supervisor.SIMULATION_MODE_REAL_TIME)
                logger.info("Simulation resumed")
                self._broadcast({"event": "started"})

            case "stop":
                self._paused = True
                self.supervisor.simulationSetMode(Supervisor.SIMULATION_MODE_PAUSE)
                logger.info("Simulation paused")
                self._broadcast({"event": "stopped"})

            case "reset":
                self.supervisor.simulationReset()
                self._prev_position = None
                logger.info("Simulation reset")
                self._broadcast({"event": "reset"})

            case "get_state":
                state = self._build_telemetry()
                if state is not None:
                    self._broadcast(state)

            case "set_telemetry_rate":
                hz = cmd.get("hz", DEFAULT_TELEMETRY_HZ)
                self._telemetry_hz = max(1.0, min(120.0, float(hz)))
                logger.info("Telemetry rate set to %.1f Hz", self._telemetry_hz)

            case "set_position":
                if self.robot_node is not None:
                    x = float(cmd.get("x", 0.0))
                    y = float(cmd.get("y", 0.0))
                    z = float(cmd.get("z", 0.05))
                    trans_field = self.robot_node.getField("translation")
                    trans_field.setSFVec3f([x, y, z])
                    logger.info("Robot position set to (%.3f, %.3f, %.3f)", x, y, z)

            case _:
                logger.warning("Unknown supervisor command: %s", action)

    # ------------------------------------------------------------------
    # Telemetry
    # ------------------------------------------------------------------

    def _build_telemetry(self) -> Optional[dict[str, Any]]:
        """Build telemetry dict from current simulation state."""
        if self.robot_node is None:
            return None

        sim_time = self.supervisor.getTime()

        # Position
        position = list(self.robot_node.getPosition())

        # Rotation (axis-angle → euler)
        orientation = list(self.robot_node.getOrientation())
        # getOrientation returns a 3x3 rotation matrix as a flat list
        # Extract euler angles from rotation matrix
        r00, r01, r02 = orientation[0], orientation[1], orientation[2]
        r10, r11, r12 = orientation[3], orientation[4], orientation[5]
        r20, r21, r22 = orientation[6], orientation[7], orientation[8]

        pitch = math.asin(max(-1.0, min(1.0, -r20)))
        if abs(math.cos(pitch)) > 1e-6:
            roll = math.atan2(r21, r22)
            yaw = math.atan2(r10, r00)
        else:
            roll = math.atan2(-r12, r11)
            yaw = 0.0

        rotation_euler = [
            math.degrees(roll),
            math.degrees(pitch),
            math.degrees(yaw),
        ]

        # Speed
        speed = 0.0
        if self._prev_position is not None:
            dt = sim_time - self._prev_time
            if dt > 0:
                dx = position[0] - self._prev_position[0]
                dy = position[1] - self._prev_position[1]
                dz = position[2] - self._prev_position[2]
                speed = math.sqrt(dx * dx + dy * dy + dz * dz) / dt
        self._prev_position = position[:]
        self._prev_time = sim_time

        # Turret / barrel angles
        turret_angle = 0.0
        barrel_angle = 0.0
        if self._turret_sensor is not None:
            turret_angle = math.degrees(self._turret_sensor.getValue())
        if self._barrel_sensor is not None:
            barrel_angle = math.degrees(self._barrel_sensor.getValue())

        # ToF distance
        tof_distance = 0.0
        if self._tof_sensor is not None:
            tof_distance = self._tof_sensor.getValue()

        # IMU
        imu_data = {"roll": 0.0, "pitch": 0.0, "yaw": 0.0}
        if self._imu is not None:
            rpy = self._imu.getRollPitchYaw()
            imu_data = {
                "roll": round(math.degrees(rpy[0]), 3),
                "pitch": round(math.degrees(rpy[1]), 3),
                "yaw": round(math.degrees(rpy[2]), 3),
            }

        return {
            "time": round(sim_time, 4),
            "position": [round(v, 5) for v in position],
            "rotation": [round(v, 3) for v in rotation_euler],
            "speed": round(speed, 4),
            "turret_angle": round(turret_angle, 3),
            "barrel_angle": round(barrel_angle, 3),
            "tof_distance": round(tof_distance, 1),
            "imu": imu_data,
        }

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------

    def run(self) -> None:
        self._start_server()

        telemetry_interval_ms = 1000.0 / self._telemetry_hz
        last_telemetry_time = 0.0

        while self.supervisor.step(self.timestep) != -1:
            self._accept_clients()

            for cmd in self._read_commands():
                self._handle_command(cmd)

            # Stream telemetry
            if self._streaming and self._clients:
                now = self.supervisor.getTime()
                # Recalculate interval in case rate changed
                telemetry_interval_s = 1.0 / self._telemetry_hz
                if now - last_telemetry_time >= telemetry_interval_s:
                    telemetry = self._build_telemetry()
                    if telemetry is not None:
                        self._broadcast(telemetry)
                    last_telemetry_time = now

        # Cleanup
        for client in self._clients:
            try:
                client.close()
            except OSError:
                pass
        if self._server_sock is not None:
            self._server_sock.close()
        logger.info("Supervisor controller shutting down")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    controller = SupervisorController()
    controller.run()


if __name__ == "__main__":
    main()
