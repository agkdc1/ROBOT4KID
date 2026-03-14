"""CAD generation module — generates OpenSCAD code for parts via LLM."""

import logging

from planning_server.app.pipeline.llm import Provider, generate_text
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
    provider: Provider = Provider.CLAUDE,
) -> str:
    """Generate OpenSCAD code for a single part.

    Args:
        part: The part specification.
        printer: Printer profile for design constraints.
        context: Additional context (e.g., related parts, assembly notes).
        model: Model override.
        provider: LLM provider to use.

    Returns:
        OpenSCAD code string.
    """
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

    code = await generate_text(
        prompt=prompt,
        system=SCAD_SYSTEM_PROMPT,
        provider=provider,
        model=model,
        max_tokens=4096,
    )

    logger.info(f"Generated SCAD for {part.id}: {len(code)} chars")
    return code
