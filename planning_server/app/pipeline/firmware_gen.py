"""Firmware generation module — generates ESP32 C++ code via LLM."""

import logging

from planning_server.app.pipeline.llm import Provider, generate_text
from shared.schemas.robot_spec import RobotSpec

logger = logging.getLogger(__name__)

FIRMWARE_SYSTEM_PROMPT = """You are an expert embedded systems programmer for ESP32-CAM with Arduino framework.

The robot uses a dual-node architecture:
- Hull Node (ESP32-CAM): WiFi AP, front camera MJPEG, L9110 dual motor control, MPU6050 gyro
- Turret Node (ESP32-CAM): WiFi STA to hull AP, gunner camera MJPEG, servo for barrel elevation,
  turret rotation motor, VL53L0X ToF sensor, firing mechanism

Communication: Hull runs as WiFi AP ("TANK_CTRL"). Turret connects as STA.
Tablet connects to hull's AP. Commands sent via WebSocket/HTTP.
Hull relays turret commands via UART over slip ring.

Generate clean, well-structured Arduino C++ code using PlatformIO conventions.
Use library dependencies: ESP32Servo, MPU6050_light or electroniccats/MPU6050.
Output ONLY the C++ code. No markdown fences.
"""


async def generate_firmware(
    robot_spec: RobotSpec,
    node: str = "hull",
    model: str | None = None,
    provider: Provider = Provider.CLAUDE,
) -> str:
    """Generate firmware code for the specified node.

    Args:
        robot_spec: Full robot specification.
        node: "hull" or "turret".
        model: Model override.
        provider: LLM provider to use.

    Returns:
        C++ source code string.
    """
    fw_config = robot_spec.firmware_config
    electronics = [e for e in robot_spec.electronics if node in e.id.lower() or node in e.host_part.lower()]

    prompt = f"""Generate the main.cpp firmware for the {node.upper()} NODE of robot "{robot_spec.name}".

Electronics on this node:
{chr(10).join(f'- {e.id}: {e.type} mounted on {e.host_part}' for e in electronics)}

Firmware config:
{fw_config}

Requirements for {node} node:
"""

    if node == "hull":
        prompt += """
- Create WiFi Access Point (SSID from config, default "TANK_CTRL")
- Serve MJPEG camera stream on port 81
- Accept WebSocket commands on port 80
- Drive 2x DC motors via L9110 (differential steering)
- Read MPU6050 gyroscope for heading
- Forward turret commands via UART Serial2
- Handle command protocol with checksum
"""
    else:
        prompt += """
- Connect to hull's WiFi AP as STA
- Serve MJPEG camera stream on port 81
- Accept WebSocket commands on port 80
- Control barrel elevation servo
- Control turret rotation motor
- Read VL53L0X ToF range sensor
- Control firing mechanism
- Receive commands via UART Serial2 from hull
"""

    code = await generate_text(
        prompt=prompt,
        system=FIRMWARE_SYSTEM_PROMPT,
        provider=provider,
        model=model,
        max_tokens=8192,
    )

    logger.info(f"Generated firmware for {node}: {len(code)} chars")
    return code
