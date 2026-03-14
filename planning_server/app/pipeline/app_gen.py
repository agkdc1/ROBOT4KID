"""Flutter app generation module — generates Dart code via Claude API."""

import logging

from anthropic import AsyncAnthropic

from planning_server.app import config
from shared.schemas.robot_spec import RobotSpec

logger = logging.getLogger(__name__)

APP_SYSTEM_PROMPT = """You are an expert Flutter/Dart developer building tablet control apps for robots.

The app runs on a 10-inch Android tablet in landscape mode. Features:
- Dual virtual joystick controls (left: movement, right: turret)
- MJPEG camera feed from ESP32-CAMs displayed as background
- HUD overlay with speed, heading, range, barrel elevation
- Button panel: Fire, Camera toggle, Resupply, Spare
- WebSocket connection to ESP32 hull node for commands
- TFLite inference for ballistics (optional)

Key Flutter packages:
- flutter_joystick for virtual joysticks
- flutter_mjpeg for camera feeds
- web_socket_channel for ESP32 communication
- tflite_flutter for edge AI
- provider for state management

Output ONLY the Dart code. No markdown fences.
"""


async def generate_app_code(
    robot_spec: RobotSpec,
    component: str = "main",
    model: str | None = None,
) -> str:
    """Generate Flutter/Dart code for a specific app component.

    Args:
        robot_spec: Full robot specification.
        component: Which component to generate (main, control_screen, joystick, etc.).
        model: Claude model to use.

    Returns:
        Dart source code string.
    """
    if not config.ANTHROPIC_API_KEY:
        raise ValueError("ANTHROPIC_API_KEY not set")

    client = AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)
    model = model or config.CLAUDE_MODEL_FAST

    prompt = f"""Generate Flutter/Dart code for the {component} component of the control app for "{robot_spec.name}".

Robot details:
- Name: {robot_spec.name}
- Hull ESP32 WiFi AP SSID: {robot_spec.firmware_config.get('wifi_ssid', 'TANK_CTRL')}
- Hull camera URL: http://192.168.4.1:81/stream
- Turret camera URL: http://192.168.4.2:81/stream
- WebSocket control: ws://192.168.4.1:80/ws

Generate the {component} file.
"""

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = await client.messages.create(
                model=model,
                max_tokens=8192,
                system=APP_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )

            code = response.content[0].text.strip()
            if code.startswith("```"):
                lines = code.split("\n")
                code = "\n".join(lines[1:])
                if code.endswith("```"):
                    code = code[:-3].strip()

            logger.info(f"Generated app code for {component}: {len(code)} chars")
            return code

        except Exception as e:
            logger.warning(f"App gen attempt {attempt + 1} failed: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"App generation failed: {e}")

    raise ValueError("App generation failed")
