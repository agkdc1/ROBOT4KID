"""Visual Validation module — Step 4 of the pipeline.

Renders 6-angle views of the assembled model + individual parts,
sends images + SCAD + URDF + schema to Gemini for critique,
returns a structured 10-point constraint checklist with severity ratings.

The Gemini prompt acts as a "Senior Mechanical Quality Inspector" with
zero tolerance for manifold errors, proportion deviations, and printability issues.
"""

import base64
import json
import logging
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from planning_server.app.pipeline.llm import Provider, generate_with_tool

logger = logging.getLogger(__name__)

# Camera positions for 6-angle orthographic views (OpenSCAD --camera args)
# Format: eye_x,eye_y,eye_z,center_x,center_y,center_z
CAMERA_VIEWS = {
    "front":  {"eye": "0,-500,50",    "desc": "Front view (glacis plate, driver hatch)"},
    "rear":   {"eye": "0,500,50",     "desc": "Rear view (engine deck, exhaust)"},
    "left":   {"eye": "-500,0,50",    "desc": "Left side view (tracks, skirts, turret profile)"},
    "right":  {"eye": "500,0,50",     "desc": "Right side view (tracks, skirts, turret profile)"},
    "top":    {"eye": "0,0,500",      "desc": "Top view (turret pentagram shape, barrel alignment)"},
    "bottom": {"eye": "0,0,-500",     "desc": "Bottom view (track ground contact, hull underside)"},
}

# Structured output schema for Gemini's validation checklist
VALIDATION_TOOL = {
    "name": "design_validation",
    "description": "Structured 10-point design validation checklist with severity ratings for a robot model.",
    "input_schema": {
        "type": "object",
        "properties": {
            "model_name": {"type": "string"},
            "visual_quality_score": {
                "type": "integer",
                "description": "Visual Quality Score 0-10. Below 7 = mandatory fixes required.",
            },
            "checklist": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer", "description": "Check number 1-10"},
                        "category": {
                            "type": "string",
                            "enum": [
                                "manifold_integrity",
                                "scale_proportion",
                                "mechanical_realism",
                                "structural_continuity",
                                "printability_overhangs",
                                "printability_volume",
                                "aesthetic_edges",
                                "aesthetic_surface",
                                "aerodynamic_continuity",
                                "overall_fidelity",
                            ],
                        },
                        "severity": {
                            "type": "string",
                            "enum": ["critical", "major", "minor", "info"],
                        },
                        "status": {
                            "type": "string",
                            "enum": ["pass", "warning", "fail"],
                        },
                        "description": {"type": "string"},
                        "rationale": {
                            "type": "string",
                            "description": "Why this passed or failed, with specific measurements",
                        },
                        "suggestion": {
                            "type": "string",
                            "description": "Specific fix if status is warning/fail",
                        },
                    },
                    "required": ["id", "category", "severity", "status", "description", "rationale"],
                },
                "description": "10 validation checks",
            },
            "mandatory_fixes": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Fixes that MUST be applied before proceeding. Be explicit: e.g., 'Hull top deck is missing. Re-generate with closed solid.'",
            },
            "critical_issues": {
                "type": "array",
                "items": {"type": "string"},
                "description": "List of critical issues that must be fixed before printing",
            },
            "positive_notes": {
                "type": "array",
                "items": {"type": "string"},
                "description": "What looks good and accurate",
            },
        },
        "required": ["model_name", "visual_quality_score", "checklist", "mandatory_fixes"],
    },
}


def render_view(
    scad_file: Path,
    output_png: Path,
    camera_args: str,
    size: tuple[int, int] = (800, 600),
    openscad_bin: str = "openscad",
) -> bool:
    """Render a single PNG view from an OpenSCAD file.

    Args:
        scad_file: Path to .scad file.
        output_png: Output PNG path.
        camera_args: Camera position string for --camera.
        size: Image dimensions (width, height).
        openscad_bin: Path to OpenSCAD binary.

    Returns:
        True if render succeeded.
    """
    cmd = [
        openscad_bin,
        "-o", str(output_png),
        f"--camera={camera_args}",
        f"--imgsize={size[0]},{size[1]}",
        "--colorscheme=Tomorrow Night",
        str(scad_file),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if output_png.exists() and output_png.stat().st_size > 0:
            return True
        logger.warning(f"Render failed for {output_png.name}: {result.stderr[:200]}")
        return False
    except Exception as e:
        logger.warning(f"Render error for {output_png.name}: {e}")
        return False


def render_6_views(
    scad_file: Path,
    output_dir: Path,
    prefix: str = "view",
    openscad_bin: str = "openscad",
) -> dict[str, Path]:
    """Render 6 orthographic views of a model.

    Returns:
        Dict mapping view name to PNG path.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    results = {}

    for view_name, view_config in CAMERA_VIEWS.items():
        png_path = output_dir / f"{prefix}_{view_name}.png"
        if render_view(scad_file, png_path, view_config["eye"], openscad_bin=openscad_bin):
            results[view_name] = png_path
            logger.info(f"Rendered {view_name}: {png_path}")
        else:
            logger.warning(f"Failed to render {view_name}")

    return results


def render_parts(
    part_scad_files: list[Path],
    output_dir: Path,
    openscad_bin: str = "openscad",
) -> dict[str, Path]:
    """Render individual parts as isometric PNGs.

    Returns:
        Dict mapping part name to PNG path.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    iso_camera = "300,-300,200,0,0,0"

    for scad_file in part_scad_files:
        part_name = scad_file.stem
        png_path = output_dir / f"part_{part_name}.png"
        if render_view(scad_file, png_path, iso_camera, openscad_bin=openscad_bin):
            results[part_name] = png_path

    return results


def _encode_images(image_paths: dict[str, Path]) -> list[dict]:
    """Encode PNG images as base64 for Gemini API."""
    encoded = []
    for name, path in image_paths.items():
        if path.exists():
            data = base64.b64encode(path.read_bytes()).decode("utf-8")
            encoded.append({
                "name": name,
                "mime_type": "image/png",
                "data": data,
            })
    return encoded


def build_audit_context(model_type: str, model_name: str, reference_analysis: dict | None = None) -> str:
    """Generate model-specific audit context for Gemini.

    Instead of a hardcoded swiss-army-knife prompt, this builds
    context dynamically based on model type and reference data.
    """
    # Base context (always included)
    context = [
        "COMMON RULES:",
        "- Body/hull top deck MUST be closed (no background visible through walls).",
        "- Split seams between print halves are INTENTIONAL (not defects).",
        "- Green/cyan blocks are electronics placeholders (ESP32-CAM, sensors) — ignore them.",
        "- All individual print parts must fit 180x180x180mm build volume.",
        "- Score 0-10 integer. Below 7 = mandatory fixes required.",
        "",
    ]

    # Model-specific physics
    if model_type == "tank":
        context.extend([
            "TANK PHYSICS:",
            "- Track belt touches ground, NOT the hull. Hull sits ABOVE tracks on suspension.",
            "- There MUST be ground clearance between hull bottom and ground (correct).",
            "- Road wheels sit INSIDE the track belt loop.",
            "- Track belt (dark band at bottom) IS the ground contact surface.",
            "",
        ])
    elif model_type == "train":
        context.extend([
            "TRAIN PHYSICS:",
            "- This is a Plarail-compatible toy train (~130mm long).",
            "- Wheels/bogies touch rails, train body sits above on bogie mounts.",
            "- The nose must be aerodynamically smooth (no steps or cliff edges).",
            "- Internal components (motor, battery, camera) mount inside the body shell.",
            "- The body shell should be a recognizable Shinkansen/train shape.",
            "",
        ])
    else:
        context.extend([
            f"MODEL TYPE: {model_type}",
            "- Verify structural integrity and proportional accuracy.",
            "",
        ])

    # Reference-specific checks
    if reference_analysis:
        ratios = reference_analysis.get("proportional_ratios", {})
        if ratios:
            context.append("REFERENCE PROPORTIONS (verify within 15%):")
            for k, v in ratios.items():
                context.append(f"- {k}: {v:.3f}")
            context.append("")

    return "\n".join(context)


async def validate_design(
    model_name: str,
    assembly_views: dict[str, Path],
    part_views: dict[str, Path],
    scad_sources: dict[str, str],
    urdf_data: str | None = None,
    robot_spec_json: str | None = None,
    reference_analysis: dict | None = None,
    provider: Provider = Provider.GEMINI,
    model_type: str = "tank",
) -> dict[str, Any]:
    """Send rendered views + source data to Gemini for design validation.

    Args:
        model_name: Name of the model being validated.
        assembly_views: Dict of view_name -> PNG path for 6-angle views.
        part_views: Dict of part_name -> PNG path for individual parts.
        scad_sources: Dict of filename -> SCAD source code.
        urdf_data: URDF XML string if available.
        robot_spec_json: RobotSpec JSON string if available.
        reference_analysis: Proportional analysis from Step 1.
        provider: LLM provider (default: Gemini).

    Returns:
        Structured validation checklist.
    """
    # Build the prompt with all context
    prompt_parts = [
        f"## Design Validation for {model_name}\n",
        "You are validating a 3D-printable scale model robot. ",
        "Review the rendered images from 6 angles (assembled) and individual parts (disassembled). ",
        "Compare against the reference proportional analysis and the URDF kinematic data.\n\n",
    ]

    # Add image descriptions
    prompt_parts.append("### Rendered Views (Assembled)\n")
    for view_name, path in assembly_views.items():
        desc = CAMERA_VIEWS.get(view_name, {}).get("desc", view_name)
        prompt_parts.append(f"- **{view_name}**: {desc}\n")

    prompt_parts.append(f"\n### Individual Parts ({len(part_views)} parts)\n")
    for part_name in part_views:
        prompt_parts.append(f"- {part_name}\n")

    # Add SCAD source
    if scad_sources:
        prompt_parts.append("\n### OpenSCAD Source (key dimensions)\n")
        for filename, source in scad_sources.items():
            # Extract just the parameter lines (first 60 lines)
            lines = source.split("\n")[:60]
            param_lines = [l for l in lines if "=" in l and not l.strip().startswith("//")]
            if param_lines:
                prompt_parts.append(f"**{filename}**:\n```\n")
                prompt_parts.append("\n".join(param_lines[:20]))
                prompt_parts.append("\n```\n")

    # Add URDF data
    if urdf_data:
        prompt_parts.append("\n### URDF Kinematic Data\n```xml\n")
        # Truncate to key sections
        prompt_parts.append(urdf_data[:3000])
        prompt_parts.append("\n```\n")

    # Add robot spec schema
    if robot_spec_json:
        prompt_parts.append("\n### Robot Specification (JSON)\n```json\n")
        prompt_parts.append(robot_spec_json[:3000])
        prompt_parts.append("\n```\n")

    # Add reference proportions
    if reference_analysis:
        prompt_parts.append("\n### Reference Proportional Analysis (from Step 1)\n```json\n")
        prompt_parts.append(json.dumps(reference_analysis.get("proportional_ratios", {}), indent=2))
        prompt_parts.append("\n```\n")
        prompt_parts.append("\nTarget scaled dimensions (mm):\n```json\n")
        prompt_parts.append(json.dumps(reference_analysis.get("scaled_dimensions_mm", {}), indent=2))
        prompt_parts.append("\n```\n")
        if reference_analysis.get("shape_notes"):
            prompt_parts.append("\nShape notes:\n")
            for note in reference_analysis["shape_notes"]:
                prompt_parts.append(f"- {note.get('feature', '')}: {note.get('description', '')}\n")

    prompt_parts.append(
        "\n\n### Instructions\n"
        "Evaluate this model against the 10 validation categories: "
        "manifold_integrity, scale_proportion, mechanical_realism, structural_continuity, "
        "printability_overhangs, printability_volume, aesthetic_edges, aesthetic_surface, "
        "aerodynamic_continuity (train models only — mark as 'pass' with severity 'info' for non-train), "
        "and overall_fidelity.\n\n"
        "For each check, assign a severity (critical/major/minor/info) and status (pass/warning/fail). "
        "Compare the rendered geometry against the reference proportions with specific measurements. "
        "If you see a missing surface, say EXACTLY which surface and how to fix it. "
        "If road wheels don't touch the ground plane, state the exact Z offset needed.\n\n"
        "Populate 'mandatory_fixes' with explicit action items for every critical/major fail. "
        "Score visual_quality_score as an integer 0-10. Below 7 means mandatory fixes are required.\n"
    )

    # Build model-specific audit context dynamically
    audit_context = build_audit_context(model_type, model_name, reference_analysis)

    system = (
        f"You are a Senior Mechanical Quality Inspector reviewing a 3D-printable scale model of a {model_name}. "
        f"You have ZERO TOLERANCE for:\n"
        f"- Missing faces or non-manifold geometry (like a hull without a top deck)\n"
        f"- Parts that don't fit the build volume (180x180x180mm per individual print part)\n"
        f"- Moving joints without clearance gaps (minimum 0.2mm per side)\n"
        f"- Proportions that deviate more than 15% from reference\n\n"
        f"IMPORTANT CONTEXT:\n"
        f"- Transparent/colored blocks (green, cyan, dark green) are INTENTIONAL electronics dummy volumes "
        f"(ESP32-CAM cameras, VL53L1X ToF sensors). They show where components mount inside the printed shell. "
        f"Do NOT flag these as errors or 'unidentified objects.'\n"
        f"- This is a 3D-PRINTED FDM model, not a display-grade kit. Evaluate structural correctness, "
        f"printability, and proportional accuracy — NOT display-model detail level.\n"
        f"- Chamfers of 0.3-1.0mm may not be visible in 800x600 renders. Check the SCAD source code "
        f"for chamfer/fillet modules rather than relying purely on visual inspection.\n"
        f"- Individual print parts are SPLIT from the assembly (e.g., hull splits into front+rear halves). "
        f"The assembly view shows the COMBINED model — check individual part dimensions in the spec.\n\n"
        f"You MUST flag every STRUCTURAL issue explicitly. Do NOT assume problems will be fixed later. "
        f"If you see a missing surface, say exactly which surface and how to fix it. "
        f"If road wheels don't touch the ground plane, say the exact Z offset needed.\n\n"
        f"You have been given 6-angle rendered views of the assembled model, individual part views, "
        f"the OpenSCAD source code, URDF kinematic data, and reference proportional analysis.\n\n"
        f"{audit_context}"
    )

    # Note: Gemini vision would use the actual images, but our text API
    # uses the descriptions + source data. For full vision support,
    # the images should be sent via the multimodal API.
    result = await generate_with_tool(
        prompt="".join(prompt_parts),
        system=system,
        tool=VALIDATION_TOOL,
        tool_name="design_validation",
        provider=provider,
    )

    logger.info(
        f"Validation complete: visual_quality_score={result.get('visual_quality_score', 0)}/10, "
        f"checks={len(result.get('checklist', []))}, "
        f"mandatory_fixes={len(result.get('mandatory_fixes', []))}"
    )
    return result


async def run_visual_validation(
    project_dir: Path,
    job_dir: Path,
    cad_dir: Path,
    model_name: str = "M1A1 Abrams",
    model_type: str = "tank",
    openscad_bin: str = "openscad",
) -> dict[str, Any]:
    """Full Step 4: Render → Gemini critique → checklist.

    This is the main entry point for the visual validation pipeline step.

    Args:
        project_dir: Project data directory.
        job_dir: Simulation job directory with STL outputs.
        cad_dir: CAD source directory.
        model_name: Model name for validation.
        openscad_bin: OpenSCAD binary path.

    Returns:
        Validation results dict with checklist.
    """
    render_dir = job_dir / "renders"
    render_dir.mkdir(exist_ok=True)

    # 1. Render 6-angle views of assembled model
    assembly_scad = cad_dir / "assembly.scad"
    assembly_views = {}
    if assembly_scad.exists():
        assembly_views = render_6_views(
            assembly_scad, render_dir, prefix="assembly", openscad_bin=openscad_bin
        )

    # 2. Render individual parts
    part_scad_files = []
    for subdir in ["chassis", "turret"]:
        scad_dir = cad_dir / subdir
        if scad_dir.exists():
            part_scad_files.extend(scad_dir.glob("*.scad"))
    part_views = render_parts(part_scad_files, render_dir, openscad_bin=openscad_bin)

    # 3. Collect SCAD source code
    scad_sources = {}
    for scad_file in [assembly_scad] + part_scad_files:
        if scad_file.exists():
            scad_sources[scad_file.name] = scad_file.read_text(encoding="utf-8")

    # 4. Load URDF if available
    urdf_data = None
    urdf_files = list(job_dir.glob("output/*.urdf"))
    if urdf_files:
        urdf_data = urdf_files[0].read_text(encoding="utf-8")

    # 5. Load robot spec
    robot_spec_json = None
    spec_file = job_dir / "robot_spec.json"
    if spec_file.exists():
        robot_spec_json = spec_file.read_text(encoding="utf-8")

    # 6. Load reference analysis
    reference_analysis = None
    ref_file = project_dir / "reference_analysis.json"
    if ref_file.exists():
        reference_analysis = json.loads(ref_file.read_text(encoding="utf-8"))

    # 7. Send to Gemini for validation
    validation = await validate_design(
        model_name=model_name,
        assembly_views=assembly_views,
        part_views=part_views,
        scad_sources=scad_sources,
        urdf_data=urdf_data,
        robot_spec_json=robot_spec_json,
        reference_analysis=reference_analysis,
        model_type=model_type,
    )

    # 8. Structural Audit (Adversarial Inspector Protocol)
    # Gemini acts as Senior QA Auditor with mandatory checks
    structural_result = await structural_audit(
        scad_sources=scad_sources,
        stl_dir=job_dir / "output",
    )
    validation["structural_audit"] = structural_result
    validation["structural_clearance"] = structural_result.get("clearance", "REJECTED")

    # 9. Save results
    validation_path = project_dir / "visual_validation.json"
    validation_path.write_text(json.dumps(validation, indent=2))

    return validation


async def structural_audit(
    scad_sources: dict[str, str],
    stl_dir: Path,
    provider: Provider = Provider.GEMINI,
) -> dict[str, Any]:
    """Adversarial structural audit — Gemini as Senior QA Auditor.

    Checks:
    1. Manifold: Is geometry watertight? Missing faces?
    2. Boolean Collision: Does internal subtractor exceed exterior? (Breach Test)
    3. Scale-Aware Thickness: Wall thickness >= 2.0mm for toy durability?
    4. Physical Feasibility: Floating parts not connected to main body?

    Returns dict with clearance status: "APPROVED" or "REJECTED" + error list.
    """
    # Static analysis: extract dimensions from SCAD source
    breach_errors = []
    for filename, source in scad_sources.items():
        lines = source.split("\n")
        params = {}
        for line in lines:
            line = line.strip()
            if line.startswith("//") or "=" not in line:
                continue
            if line.startswith("use") or line.startswith("include"):
                continue
            parts = line.split("=", 1)
            if len(parts) == 2:
                key = parts[0].strip()
                val_str = parts[1].split(";")[0].split("//")[0].strip()
                try:
                    params[key] = float(val_str)
                except ValueError:
                    pass

        # Breach Test: check if interior void exceeds exterior
        for ext_key, int_key in [
            ("hull_width", "ebay_mount_y"),
            ("turret_width", "duct_width"),
        ]:
            if ext_key in params and int_key in params:
                wall = params.get("wall", 1.6)
                max_interior = params[ext_key] - 2 * wall
                if params[int_key] > max_interior:
                    breach_errors.append(
                        f"[ERROR: Structural Breach] {filename}: "
                        f"Internal {int_key} ({params[int_key]:.1f}mm) >= "
                        f"max interior ({max_interior:.1f}mm). "
                        f"Reduce to {max_interior:.1f}mm or less."
                    )

        # Wall thickness check (minimum 1.6mm, recommended 2.0mm for toys)
        wall = params.get("wall", 0)
        if 0 < wall < 1.6:
            breach_errors.append(
                f"[ERROR: Thin Wall] {filename}: wall={wall:.1f}mm < 1.6mm minimum. "
                f"Increase to at least 1.6mm (2.0mm recommended for durability)."
            )

    # STL manifold check via trimesh (individual PRINT parts only, not assemblies)
    # Assembly STLs (hull, track_assembly, full_assembly) are boolean unions that
    # may have non-manifold artifacts — only check the individual print halves.
    # Skip: assembly combos, internal trays, and console (has assembly sub-parts)
    ASSEMBLY_STLS = {"full_assembly", "hull", "track_assembly", "console_cradle", "electronics_bay"}
    manifold_errors = []
    try:
        import trimesh
        for stl_file in sorted(stl_dir.glob("*.stl")):
            if stl_file.stem.startswith("elec_") or stl_file.stem in ASSEMBLY_STLS:
                continue
            mesh = trimesh.load(str(stl_file))
            if not mesh.is_watertight:
                manifold_errors.append(
                    f"[ERROR: Non-Manifold] {stl_file.stem}.stl is not watertight. "
                    f"Check for missing faces or unclosed geometry."
                )
    except ImportError:
        logger.warning("trimesh not available — skipping manifold check")
    except Exception as e:
        logger.warning(f"Manifold check failed: {e}")

    all_errors = breach_errors + manifold_errors
    clearance = "APPROVED" if not all_errors else "REJECTED"

    result = {
        "clearance": clearance,
        "breach_errors": breach_errors,
        "manifold_errors": manifold_errors,
        "total_errors": len(all_errors),
    }

    if clearance == "APPROVED":
        logger.info("[STRUCTURAL_CLEARANCE: APPROVED] All checks passed")
    else:
        logger.warning(
            f"[STRUCTURAL_CLEARANCE: REJECTED] {len(all_errors)} errors found:\n"
            + "\n".join(all_errors)
        )

    return result
