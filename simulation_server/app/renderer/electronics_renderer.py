"""Render electronic component dummy volumes to STL files."""

import logging
from pathlib import Path

from shared.electronics_catalog import lookup
from simulation_server.app.renderer.openscad import render_scad_to_stl

logger = logging.getLogger(__name__)

# Path to the electronics SCAD library (relative to project root)
_LIBS_DIR = Path(__file__).resolve().parent.parent.parent.parent / "cad" / "libs"


async def render_electronic_component(
    component_type: str,
    output_path: Path,
) -> tuple[bool, str]:
    """Render an electronic component dummy to STL.

    Args:
        component_type: The ElectronicComponent.type string.
        output_path: Where to write the STL file.

    Returns:
        (success, message) tuple.
    """
    info = lookup(component_type)
    if info is None:
        return False, f"Unknown component type: {component_type}"

    # Generate self-contained SCAD that uses the electronics library
    scad_code = (
        f'use <{_LIBS_DIR.as_posix()}/electronics.scad>\n'
        f'$fn = 64;\n'
        f'{info.scad_module}();\n'
    )

    return await render_scad_to_stl(
        scad_code=scad_code,
        output_path=output_path,
    )
