"""NLP parsing module — parses natural language into RobotSpec via LLM."""

import logging

from planning_server.app.pipeline.llm import Provider, generate_with_tool
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
    provider: Provider = Provider.CLAUDE,
) -> RobotSpec:
    """Parse a natural language prompt into a RobotSpec using LLM.

    Args:
        prompt: Natural language description of the robot.
        model: Model override.
        provider: LLM provider to use.

    Returns:
        Parsed RobotSpec.

    Raises:
        ValueError: If the response cannot be parsed.
    """
    result = await generate_with_tool(
        prompt=prompt,
        system=SYSTEM_PROMPT,
        tool=ROBOT_SPEC_TOOL,
        tool_name="robot_specification",
        provider=provider,
        model=model,
    )

    spec = RobotSpec.model_validate(result)
    logger.info(f"Parsed RobotSpec: {spec.name} with {len(spec.parts)} parts")
    return spec
