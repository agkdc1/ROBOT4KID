"""CAD generation module — uses Claude API to generate OpenSCAD code for parts."""

import logging

from anthropic import AsyncAnthropic

from planning_server.app import config
from shared.schemas.robot_spec import PartSpec, PrinterProfile

logger = logging.getLogger(__name__)

SCAD_SYSTEM_PROMPT = """You are an expert OpenSCAD programmer specializing in 3D-printable robot parts.

Design rules for Bambu Lab A1 Mini (PLA):
- Max part size: 180 x 180 x 180mm. Parts exceeding this must be split.
- Wall thickness: minimum 1.2mm (3 perimeters at 0.4mm nozzle)
- M4 screw holes: 4.4mm diameter (+0.4mm clearance)
- M4 screw shafts: 3.8mm diameter (-0.2mm for strength)
- Print tolerance: 0.2mm for mating surfaces
- Max overhang angle: 45° without supports
- Use chamfers and fillets to reduce overhangs

Code style:
- Use modules for reusable geometry
- Put all dimensions as variables at the top
- Include $fn=64 for curved surfaces (set lower for drafts)
- Comment each section
- Use difference() for holes, union() for joining
- Center parts at origin for easy assembly

Output ONLY the OpenSCAD code. No markdown fences or explanations.
"""


async def generate_scad_for_part(
    part: PartSpec,
    printer: PrinterProfile,
    context: str = "",
    model: str | None = None,
) -> str:
    """Generate OpenSCAD code for a single part.

    Args:
        part: The part specification.
        printer: Printer profile for design constraints.
        context: Additional context (e.g., related parts, assembly notes).
        model: Claude model to use.

    Returns:
        OpenSCAD code string.
    """
    if not config.ANTHROPIC_API_KEY:
        raise ValueError("ANTHROPIC_API_KEY not set")

    client = AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)
    model = model or config.CLAUDE_MODEL_FAST

    prompt = f"""Generate OpenSCAD code for this part:

Part ID: {part.id}
Name: {part.name}
Category: {part.category}
Target dimensions: {part.dimensions_mm[0]:.0f} x {part.dimensions_mm[1]:.0f} x {part.dimensions_mm[2]:.0f} mm
Requires splitting: {part.requires_splitting}

Printer constraints:
- Build volume: {printer.build_volume_mm[0]:.0f} x {printer.build_volume_mm[1]:.0f} x {printer.build_volume_mm[2]:.0f} mm
- Material: {printer.material.value}
- Wall thickness: {printer.wall_thickness_mm}mm
- Tolerance: {printer.tolerance_mm}mm

{f'Additional context: {context}' if context else ''}

Generate complete, renderable OpenSCAD code for this part.
"""

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = await client.messages.create(
                model=model,
                max_tokens=4096,
                system=SCAD_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )

            code = response.content[0].text.strip()

            # Strip markdown fences if present
            if code.startswith("```"):
                lines = code.split("\n")
                code = "\n".join(lines[1:])
                if code.endswith("```"):
                    code = code[:-3].strip()

            logger.info(f"Generated SCAD for {part.id}: {len(code)} chars")
            return code

        except Exception as e:
            logger.warning(f"SCAD generation attempt {attempt + 1} failed for {part.id}: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"SCAD generation failed for {part.id}: {e}")

    raise ValueError(f"SCAD generation failed for {part.id}")
