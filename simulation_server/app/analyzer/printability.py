"""Printability analysis for 3D-printed parts."""

import logging
from pathlib import Path

from shared.schemas.robot_spec import PrinterProfile
from shared.schemas.simulation_feedback import PrintabilityResult, FeedbackItem, SeverityLevel
from simulation_server.app.renderer.stl_utils import analyze_stl, compute_overhang_percentage

logger = logging.getLogger(__name__)

# Rough estimates
PLA_DENSITY_G_PER_MM3 = 0.00124
INFILL_FACTOR = 0.20  # 20% infill
PRINT_SPEED_MM3_PER_MIN = 150.0  # Rough volumetric flow rate


def check_printability(
    stl_path: Path,
    part_id: str,
    printer: PrinterProfile,
    part_dimensions_mm: tuple[float, float, float] | None = None,
) -> tuple[PrintabilityResult, list[FeedbackItem]]:
    """Analyze a part for printability on the given printer.

    Returns (PrintabilityResult, list of FeedbackItem).
    """
    feedback_items: list[FeedbackItem] = []

    # Analyze the STL
    analysis = analyze_stl(stl_path)

    dims = analysis["dimensions_mm"]
    if dims == (0.0, 0.0, 0.0) and part_dimensions_mm:
        dims = part_dimensions_mm

    volume = analysis["volume_mm3"]

    # Check build volume
    bv = printer.build_volume_mm
    fits = all(d <= b for d, b in zip(dims, bv))

    if not fits:
        over_dims = []
        for axis, d, b in zip(["X", "Y", "Z"], dims, bv):
            if d > b:
                over_dims.append(f"{axis}: {d:.1f}mm > {b:.1f}mm")
        feedback_items.append(FeedbackItem(
            category="printability",
            severity=SeverityLevel.ERROR,
            part_id=part_id,
            message=f"Part exceeds build volume: {', '.join(over_dims)}",
            data={"dimensions_mm": dims, "build_volume_mm": bv},
            suggestion="Split the part along natural seams with alignment pins and M4 bolt holes.",
        ))

    # Check manifold
    if not analysis["is_manifold"]:
        feedback_items.append(FeedbackItem(
            category="printability",
            severity=SeverityLevel.WARNING,
            part_id=part_id,
            message="Mesh is not watertight (non-manifold). May cause slicing issues.",
            data={},
            suggestion="Check OpenSCAD code for unclosed geometry or overlapping surfaces.",
        ))

    # Overhang analysis
    overhang_pct = compute_overhang_percentage(stl_path)
    needs_supports = overhang_pct > 15.0

    if needs_supports:
        severity = SeverityLevel.WARNING if overhang_pct < 40 else SeverityLevel.ERROR
        feedback_items.append(FeedbackItem(
            category="printability",
            severity=severity,
            part_id=part_id,
            message=f"High overhang: {overhang_pct:.1f}% of faces exceed 45°.",
            data={"overhang_percentage": overhang_pct},
            suggestion="Redesign to reduce overhangs, add chamfers, or plan for support material.",
        ))

    # Estimate print time and filament
    shell_volume = volume * 0.3  # rough shell estimate
    infill_volume = volume * INFILL_FACTOR * 0.7
    total_print_volume = shell_volume + infill_volume
    est_time_min = total_print_volume / PRINT_SPEED_MM3_PER_MIN if PRINT_SPEED_MM3_PER_MIN > 0 else 0
    est_filament_g = total_print_volume * PLA_DENSITY_G_PER_MM3

    result = PrintabilityResult(
        part_id=part_id,
        fits_build_volume=fits,
        overhang_percentage=overhang_pct,
        estimated_print_time_min=round(est_time_min, 1),
        estimated_filament_grams=round(est_filament_g, 1),
        needs_supports=needs_supports,
        recommended_orientation=(0.0, 0.0, 0.0),
    )

    return result, feedback_items
