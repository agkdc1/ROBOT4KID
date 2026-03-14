"""NLP parsing module — uses Claude API to parse natural language into RobotSpec."""

import json
import logging

from anthropic import AsyncAnthropic

from planning_server.app import config
from shared.schemas.robot_spec import RobotSpec

logger = logging.getLogger(__name__)

# JSON Schema for the robot_specification tool
ROBOT_SPEC_TOOL = {
    "name": "robot_specification",
    "description": (
        "Generate a structured robot specification from a natural language description. "
        "Include all mechanical parts, joints, electronics, and firmware configuration."
    ),
    "input_schema": RobotSpec.model_json_schema(),
}

SYSTEM_PROMPT = """You are a robotics design engineer. Given a natural language description of a robot,
you generate a complete RobotSpec JSON. Focus on:

1. Breaking the robot into printable mechanical parts (each ≤ 180x180x180mm for Bambu A1 Mini)
2. Defining joints between parts (fixed, revolute, continuous, prismatic)
3. Specifying electronics (ESP32-CAM, motors, sensors, servos)
4. Setting firmware configuration (WiFi, pin mappings)

Use M4 screws as the primary fastener. All dimensions in millimeters.
Parts that exceed the build volume should have requires_splitting=True.

For a tank/tracked vehicle:
- Hull chassis with battery compartment and motor mounts
- Track assemblies (left and right)
- Turret body with rotation mechanism
- Gun barrel with elevation trunnion
- Console cradle for tablet control

Default printer: Bambu Lab A1 Mini (180x180x180mm, PLA, 0.4mm nozzle, 0.2mm layer height).
"""


async def parse_nl_to_robot_spec(
    prompt: str,
    model: str | None = None,
) -> RobotSpec:
    """Parse a natural language prompt into a RobotSpec using Claude API.

    Args:
        prompt: Natural language description of the robot.
        model: Claude model to use (defaults to fast model).

    Returns:
        Parsed RobotSpec.

    Raises:
        ValueError: If Claude's response cannot be parsed.
    """
    if not config.ANTHROPIC_API_KEY:
        raise ValueError("ANTHROPIC_API_KEY not set. Configure it in environment variables.")

    client = AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)
    model = model or config.CLAUDE_MODEL_FAST

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = await client.messages.create(
                model=model,
                max_tokens=8192,
                system=SYSTEM_PROMPT,
                tools=[ROBOT_SPEC_TOOL],
                tool_choice={"type": "tool", "name": "robot_specification"},
                messages=[{"role": "user", "content": prompt}],
            )

            # Extract tool_use block
            for block in response.content:
                if block.type == "tool_use" and block.name == "robot_specification":
                    spec = RobotSpec.model_validate(block.input)
                    logger.info(f"Parsed RobotSpec: {spec.name} with {len(spec.parts)} parts")
                    return spec

            raise ValueError("No robot_specification tool_use in response")

        except Exception as e:
            logger.warning(f"NLP parse attempt {attempt + 1} failed: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"Failed to parse after {config.CLAUDE_MAX_RETRIES} attempts: {e}")

    raise ValueError("NLP parsing failed")
