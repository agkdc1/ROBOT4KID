"""Tank controller for Webots — receives binary TankCommand packets over TCP.

Listens on TCP port 10200 for commands using the same binary protocol as
the ESP32 firmware (see embedded/lib/shared/protocol.h). Drives the
differential-drive motors and turret/barrel joints accordingly.

Protocol (TankCommand struct, 10 bytes, packed):
    header      : uint8   = 0xAA
    type        : uint8   (CMD_MOVE=0x01, CMD_TURRET=0x02, CMD_FIRE=0x03,
                           CMD_CAMERA=0x04, CMD_STATUS=0x05, CMD_HEARTBEAT=0x06)
    left_speed  : int8    (-100..+100)
    right_speed : int8    (-100..+100)
    turret_angle: int16   (degrees x10, 0..3600)
    barrel_elev : int8    (-10..+45 degrees)
    fire        : uint8   (0 or 1)
    camera_mode : uint8   (0=driver, 1=gunner, 2=split)
    checksum    : uint8   (XOR of preceding bytes)

Status response (TankStatus struct, 11 bytes, packed):
    header      : uint8   = 0xAA
    type        : uint8   = 0x05
    heading     : int16   (degrees x10)
    pitch       : int16   (degrees x10)
    roll        : int16   (degrees x10)
    range_mm    : uint16
    battery_pct : uint8
    checksum    : uint8
"""

from __future__ import annotations

import logging
import math
import select
import socket
import struct
import sys
import time
from typing import Optional

# Webots controller API
try:
    from controller import Robot  # type: ignore[import-untyped]
except ImportError:
    # Allow linting / import outside Webots
    Robot = None  # type: ignore[assignment,misc]

# ---------------------------------------------------------------------------
# Constants — mirror embedded/lib/shared/protocol.h
# ---------------------------------------------------------------------------
PACKET_HEADER = 0xAA

CMD_MOVE = 0x01
CMD_TURRET = 0x02
CMD_FIRE = 0x03
CMD_CAMERA = 0x04
CMD_STATUS = 0x05
CMD_HEARTBEAT = 0x06

# struct TankCommand  (10 bytes, little-endian, packed)
TANK_CMD_FMT = "<BBbbhbBBB"
TANK_CMD_SIZE = struct.calcsize(TANK_CMD_FMT)  # 10

# struct TankStatus  (11 bytes, little-endian, packed)
TANK_STATUS_FMT = "<BBhhhHBB"
TANK_STATUS_SIZE = struct.calcsize(TANK_STATUS_FMT)  # 11

TCP_PORT = 10200
MAX_MOTOR_SPEED = 10.0  # rad/s — matches world file RotationalMotor maxVelocity

logging.basicConfig(
    level=logging.INFO,
    format="[tank_controller] %(levelname)s %(message)s",
)
logger = logging.getLogger("tank_controller")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _xor_checksum(data: bytes) -> int:
    cs = 0
    for b in data:
        cs ^= b
    return cs


def _validate_command(raw: bytes) -> bool:
    if len(raw) < TANK_CMD_SIZE:
        return False
    if raw[0] != PACKET_HEADER:
        return False
    expected = _xor_checksum(raw[: TANK_CMD_SIZE - 1])
    return expected == raw[TANK_CMD_SIZE - 1]


def _build_status(
    heading_deg10: int,
    pitch_deg10: int,
    roll_deg10: int,
    range_mm: int,
    battery_pct: int = 100,
) -> bytes:
    """Build a TankStatus response packet."""
    payload = struct.pack(
        "<BBhhhHB",
        PACKET_HEADER,
        CMD_STATUS,
        heading_deg10,
        pitch_deg10,
        roll_deg10,
        range_mm,
        battery_pct,
    )
    cs = _xor_checksum(payload)
    return payload + struct.pack("B", cs)


# ---------------------------------------------------------------------------
# Controller
# ---------------------------------------------------------------------------

class TankController:
    """Webots tank controller with TCP command interface."""

    def __init__(self) -> None:
        if Robot is None:
            raise RuntimeError("Must be run inside Webots (controller module not found)")

        self.robot = Robot()
        self.timestep: int = int(self.robot.getBasicTimeStep())

        # Motors
        self.left_motor = self.robot.getDevice("left_motor")
        self.right_motor = self.robot.getDevice("right_motor")
        self.turret_motor = self.robot.getDevice("turret_motor")
        self.barrel_motor = self.robot.getDevice("barrel_motor")

        # Set motors to velocity control mode
        self.left_motor.setPosition(float("inf"))
        self.right_motor.setPosition(float("inf"))
        self.left_motor.setVelocity(0.0)
        self.right_motor.setVelocity(0.0)

        # Turret/barrel start in position control mode
        self.turret_motor.setPosition(0.0)
        self.barrel_motor.setPosition(0.0)

        # Sensors
        self.turret_sensor = self.robot.getDevice("turret_sensor")
        self.barrel_sensor = self.robot.getDevice("barrel_sensor")
        self.left_encoder = self.robot.getDevice("left_encoder")
        self.right_encoder = self.robot.getDevice("right_encoder")
        self.tof_sensor = self.robot.getDevice("tof_sensor")
        self.imu = self.robot.getDevice("imu")
        self.accelerometer = self.robot.getDevice("accelerometer")
        self.gyro = self.robot.getDevice("gyro")

        # Cameras
        self.hull_cam = self.robot.getDevice("hull_cam")
        self.turret_cam = self.robot.getDevice("turret_cam")

        # Enable sensors at controller timestep
        for sensor in (
            self.turret_sensor, self.barrel_sensor,
            self.left_encoder, self.right_encoder,
            self.tof_sensor, self.imu,
            self.accelerometer, self.gyro,
        ):
            sensor.enable(self.timestep)

        self.hull_cam.enable(self.timestep)
        self.turret_cam.enable(self.timestep)

        # TCP server
        self._server_sock: Optional[socket.socket] = None
        self._client_sock: Optional[socket.socket] = None
        self._recv_buf = bytearray()

        logger.info("Tank controller initialised (timestep=%d ms)", self.timestep)

    # ------------------------------------------------------------------
    # Networking
    # ------------------------------------------------------------------

    def _start_server(self) -> None:
        self._server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server_sock.bind(("0.0.0.0", TCP_PORT))
        self._server_sock.listen(1)
        self._server_sock.setblocking(False)
        logger.info("TCP server listening on port %d", TCP_PORT)

    def _accept_client(self) -> None:
        if self._server_sock is None:
            return
        readable, _, _ = select.select([self._server_sock], [], [], 0)
        if readable:
            conn, addr = self._server_sock.accept()
            conn.setblocking(False)
            if self._client_sock is not None:
                try:
                    self._client_sock.close()
                except OSError:
                    pass
            self._client_sock = conn
            self._recv_buf.clear()
            logger.info("Client connected from %s", addr)

    def _read_commands(self) -> list[tuple]:
        """Non-blocking read — returns list of parsed TankCommand tuples."""
        commands: list[tuple] = []
        if self._client_sock is None:
            return commands

        try:
            readable, _, _ = select.select([self._client_sock], [], [], 0)
            if readable:
                data = self._client_sock.recv(4096)
                if not data:
                    logger.info("Client disconnected")
                    self._client_sock.close()
                    self._client_sock = None
                    return commands
                self._recv_buf.extend(data)
        except (ConnectionResetError, OSError):
            logger.warning("Client connection lost")
            self._client_sock = None
            return commands

        # Extract complete packets
        while len(self._recv_buf) >= TANK_CMD_SIZE:
            # Scan for header
            try:
                idx = self._recv_buf.index(PACKET_HEADER)
            except ValueError:
                self._recv_buf.clear()
                break

            if idx > 0:
                # Discard garbage before header
                del self._recv_buf[:idx]

            if len(self._recv_buf) < TANK_CMD_SIZE:
                break

            raw = bytes(self._recv_buf[:TANK_CMD_SIZE])
            if _validate_command(raw):
                parsed = struct.unpack(TANK_CMD_FMT, raw)
                commands.append(parsed)
                del self._recv_buf[:TANK_CMD_SIZE]
            else:
                # Bad checksum — skip this header byte and rescan
                del self._recv_buf[0:1]

        return commands

    def _send_status(self) -> None:
        """Send a TankStatus packet to the connected client."""
        if self._client_sock is None:
            return

        imu_values = self.imu.getRollPitchYaw()
        roll_deg10 = int(math.degrees(imu_values[0]) * 10)
        pitch_deg10 = int(math.degrees(imu_values[1]) * 10)
        heading_deg10 = int(math.degrees(imu_values[2]) * 10)

        tof_val = self.tof_sensor.getValue()
        range_mm = max(0, min(65535, int(tof_val)))

        status_pkt = _build_status(heading_deg10, pitch_deg10, roll_deg10, range_mm)

        try:
            self._client_sock.sendall(status_pkt)
        except (BrokenPipeError, ConnectionResetError, OSError):
            logger.warning("Failed to send status — client disconnected")
            self._client_sock = None

    # ------------------------------------------------------------------
    # Command handling
    # ------------------------------------------------------------------

    def _handle_command(self, cmd: tuple) -> None:
        """Process a single parsed TankCommand tuple."""
        (header, cmd_type, left_speed, right_speed,
         turret_angle, barrel_elev, fire, camera_mode, checksum) = cmd

        match cmd_type:
            case 0x01:  # CMD_MOVE
                left_vel = (left_speed / 100.0) * MAX_MOTOR_SPEED
                right_vel = (right_speed / 100.0) * MAX_MOTOR_SPEED
                self.left_motor.setVelocity(left_vel)
                self.right_motor.setVelocity(right_vel)

            case 0x02:  # CMD_TURRET
                turret_rad = math.radians(turret_angle / 10.0)
                barrel_rad = math.radians(barrel_elev)
                self.turret_motor.setPosition(turret_rad)
                self.barrel_motor.setPosition(barrel_rad)

            case 0x03:  # CMD_FIRE
                if fire:
                    logger.info("FIRE command received!")

            case 0x04:  # CMD_CAMERA
                logger.debug("Camera mode set to %d", camera_mode)

            case 0x05:  # CMD_STATUS (request)
                self._send_status()

            case 0x06:  # CMD_HEARTBEAT
                pass  # acknowledge by sending status
                self._send_status()

            case _:
                logger.warning("Unknown command type 0x%02X", cmd_type)

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------

    def run(self) -> None:
        self._start_server()
        status_interval_steps = max(1, int(200 / self.timestep))  # ~5 Hz
        step_count = 0

        while self.robot.step(self.timestep) != -1:
            self._accept_client()

            for cmd in self._read_commands():
                self._handle_command(cmd)

            # Periodic status broadcast
            step_count += 1
            if step_count % status_interval_steps == 0 and self._client_sock is not None:
                self._send_status()

        # Cleanup
        if self._client_sock is not None:
            self._client_sock.close()
        if self._server_sock is not None:
            self._server_sock.close()
        logger.info("Tank controller shutting down")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    controller = TankController()
    controller.run()


if __name__ == "__main__":
    main()
