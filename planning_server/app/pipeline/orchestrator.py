"""Pipeline orchestrator — sequences pipeline steps with progress reporting."""

import asyncio
import json
import logging
import os
import uuid
from pathlib import Path

from planning_server.app import config
from planning_server.app.pipeline.llm import Provider, generate_with_tool
from planning_server.app.pipeline.nlp import parse_nl_to_robot_spec
from planning_server.app.pipeline.cad_gen import generate_scad_for_part
from planning_server.app.pipeline.blender_render import render_pro_shots
from planning_server.app.pipeline.reference_search import search_and_analyze
from planning_server.app.pipeline.visual_validation import run_visual_validation
from planning_server.app.simulation_client.client import SimulationClient
from shared.schemas.robot_spec import RobotSpec

logger = logging.getLogger(__name__)


class PipelineProgress:
    """Tracks pipeline progress for WebSocket reporting."""

    def __init__(self):
        self.steps: list[dict] = []
        self.current_step: str = ""
        self.current_progress: float = 0.0
        self.error: str | None = None

    def update(self, step: str, progress: float, message: str = ""):
        self.current_step = step
        self.current_progress = progress
        self.steps.append({"step": step, "progress": progress, "message": message})

    def to_dict(self) -> dict:
        return {
            "current_step": self.current_step,
            "progress": self.current_progress,
            "steps": self.steps,
            "error": self.error,
        }


def _needs_refinement(feedback: dict) -> bool:
    """Check if simulation feedback indicates issues worth fixing."""
    score = feedback.get("overall_score", 1.0)
    if score >= 0.8:
        return False
    # Check for critical/error items
    for item in feedback.get("feedback_items", []):
        if item.get("severity") in ("critical", "error"):
            return True
    return score < 0.6


def _build_refinement_prompt(spec: RobotSpec, feedback: dict) -> str:
    """Build a refinement prompt from simulation feedback."""
    issues = []
    for item in feedback.get("feedback_items", []):
        severity = item.get("severity", "info")
        msg = item.get("message", "")
        part_id = item.get("part_id", "")
        suggestion = item.get("suggestion", "")
        if severity in ("critical", "error", "warning"):
            issue = f"- [{severity.upper()}] {msg}"
            if part_id:
                issue += f" (part: {part_id})"
            if suggestion:
                issue += f" — Suggestion: {suggestion}"
            issues.append(issue)

    # Printability issues
    for pr in feedback.get("printability_results", []):
        if not pr.get("fits_build_volume", True):
            dims = pr.get("dimensions_mm", [0, 0, 0])
            issues.append(
                f"- [PRINTABILITY] Part '{pr.get('part_id', '?')}' exceeds build volume "
                f"({dims[0]:.0f}x{dims[1]:.0f}x{dims[2]:.0f}mm). Max: 180x180x180mm."
            )

    score = feedback.get("overall_score", 0)
    return (
        f"The robot design scored {score:.1%} in simulation. "
        f"Fix these issues:\n\n" + "\n".join(issues) + "\n\n"
        f"Modify the RobotSpec to address these problems. "
        f"Keep changes minimal — only fix what's broken."
    )


async def _refine_spec(current_spec: RobotSpec, refinement_prompt: str) -> RobotSpec:
    """Ask the LLM to refine a RobotSpec based on feedback."""
    from planning_server.app.pipeline.nlp import ROBOT_SPEC_TOOL, SYSTEM_PROMPT

    full_prompt = (
        f"Current robot specification:\n"
        f"```json\n{current_spec.model_dump_json(indent=2)}\n```\n\n"
        f"{refinement_prompt}"
    )

    result = await generate_with_tool(
        prompt=full_prompt,
        system=SYSTEM_PROMPT + "\n\nYou are refining an existing design. Keep the overall structure "
        "and only fix the specific issues mentioned. Preserve part IDs where possible.",
        tool=ROBOT_SPEC_TOOL,
        tool_name="robot_specification",
    )

    return RobotSpec.model_validate(result)


async def run_pipeline(
    prompt: str,
    project_id: int,
    progress: PipelineProgress | None = None,
) -> dict:
    """Execute the full NL-to-robot pipeline.

    Steps:
    1. NLP Parse: Natural language → RobotSpec
    2. CAD Generation: Generate OpenSCAD code for each part
    3. Simulation: Submit to simulation server
    4. Return results

    Args:
        prompt: Natural language description.
        project_id: Project ID for file storage.
        progress: Optional progress tracker.

    Returns:
        Pipeline results dict.
    """
    progress = progress or PipelineProgress()
    project_dir = config.PROJECTS_DIR / str(project_id)
    project_dir.mkdir(parents=True, exist_ok=True)

    results = {
        "prompt": prompt,
        "project_id": project_id,
        "reference_analysis": None,
        "robot_spec": None,
        "simulation_job_id": None,
        "simulation_feedback": None,
        "errors": [],
    }

    # Step 0: Reference Search (Sonnet generates queries → web search → Gemini analyzes)
    progress.update("reference_search", 0.0, "Searching for reference specifications...")
    reference_context = ""
    try:
        analysis = await search_and_analyze(prompt)
        results["reference_analysis"] = analysis

        # Save analysis
        analysis_path = project_dir / "reference_analysis.json"
        analysis_path.write_text(json.dumps(analysis, indent=2))

        # Build context string for NLP step
        model_name = analysis.get("model_name", "")
        scaled = analysis.get("scaled_dimensions_mm", {})
        ratios = analysis.get("proportional_ratios", {})
        shape_notes = analysis.get("shape_notes", [])

        reference_context = (
            f"\n\n## Reference Proportions for {model_name}\n"
            f"Scaled dimensions (mm): {json.dumps(scaled, indent=2)}\n"
            f"Proportional ratios: {json.dumps(ratios, indent=2)}\n"
            f"Shape notes:\n"
            + "\n".join(
                f"- {n.get('feature', '')}: {n.get('description', '')} "
                f"({n.get('angle_degrees', '')}°)" if n.get('angle_degrees') else
                f"- {n.get('feature', '')}: {n.get('description', '')}"
                for n in shape_notes
            )
        )

        progress.update("reference_search", 1.0, f"Reference analysis complete: {model_name}")
        logger.info(f"Reference analysis complete for {model_name}")
    except Exception as e:
        logger.warning(f"Reference search failed (continuing without): {e}")
        results["errors"].append(f"Reference search: {e}")
        progress.update("reference_search", 1.0, f"Reference search skipped: {e}")

    # Step 1: NLP Parse (enriched with reference data)
    enriched_prompt = prompt + reference_context
    progress.update("nlp_parse", 0.0, "Parsing natural language description...")
    try:
        robot_spec = await parse_nl_to_robot_spec(enriched_prompt)
        results["robot_spec"] = robot_spec.model_dump()
        progress.update("nlp_parse", 1.0, f"Parsed: {robot_spec.name} with {len(robot_spec.parts)} parts")

        # Save spec
        spec_path = project_dir / "robot_spec.json"
        spec_path.write_text(robot_spec.model_dump_json(indent=2))

    except Exception as e:
        progress.error = f"NLP parsing failed: {e}"
        results["errors"].append(str(e))
        return results

    # Step 2: CAD Generation
    progress.update("cad_generation", 0.0, "Generating OpenSCAD code...")
    scad_dir = project_dir / "scad"
    scad_dir.mkdir(exist_ok=True)

    for i, part in enumerate(robot_spec.parts):
        try:
            part_progress = (i + 1) / len(robot_spec.parts)
            progress.update("cad_generation", part_progress, f"Generating {part.name}...")

            scad_code = await generate_scad_for_part(part, robot_spec.printer)
            part.scad_code = scad_code

            # Save SCAD file
            scad_path = scad_dir / f"{part.id}.scad"
            scad_path.write_text(scad_code)

        except Exception as e:
            logger.warning(f"SCAD generation failed for {part.id}: {e}")
            results["errors"].append(f"SCAD gen failed for {part.id}: {e}")

    # Update spec with SCAD code
    spec_path = project_dir / "robot_spec.json"
    spec_path.write_text(robot_spec.model_dump_json(indent=2))

    # Gate 1: Physics & Layout Validation (blockout primitives only)
    # "Fail fast, fail cheap" — validate proportions before spending tokens on detail
    GATE1_MAX_ITERATIONS = int(os.getenv("GATE1_MAX_ITERATIONS", "2"))
    gate1_round = 0
    progress.update("gate1_validation", 0.0, "Gate 1: Validating physics & layout...")

    while gate1_round < GATE1_MAX_ITERATIONS:
        try:
            # Submit to sim server for STL rendering
            gate1_job_id = str(uuid.uuid4())
            sim_client_g1 = SimulationClient()
            await sim_client_g1.submit_simulation(
                job_id=gate1_job_id, robot_spec=robot_spec, simulation_type="render_only",
            )
            gate1_feedback = await sim_client_g1.wait_for_feedback(gate1_job_id, timeout=120)

            # Run visual validation (6-angle renders → composite → Gemini)
            job_dir_g1 = config.SIM_JOBS_DIR / gate1_job_id if hasattr(config, "SIM_JOBS_DIR") else None
            if job_dir_g1 and job_dir_g1.exists():
                gate1_result = await run_visual_validation(
                    project_dir=project_dir,
                    job_dir=job_dir_g1,
                    cad_dir=scad_dir.parent,
                    model_name=robot_spec.name,
                )
                gate1_score = gate1_result.get("visual_quality_score", 0)
                results["gate1_validation"] = gate1_result

                # Check structural clearance from adversarial audit
                structural_clearance = gate1_result.get("structural_clearance", "REJECTED")
                structural_audit = gate1_result.get("structural_audit", {})

                if gate1_score >= 7 and structural_clearance == "APPROVED":
                    progress.update("gate1_validation", 1.0,
                                    f"Gate 1 PASSED (score: {gate1_score}/10, "
                                    f"STRUCTURAL_CLEARANCE: APPROVED)")
                    break

                if structural_clearance == "REJECTED":
                    logger.warning(
                        f"[STRUCTURAL_CLEARANCE: REJECTED] "
                        f"{structural_audit.get('total_errors', 0)} errors"
                    )

                # Gate 1 failed — fix issues and retry
                gate1_round += 1
                logger.info(f"Gate 1 round {gate1_round}: score={gate1_score}/10, iterating...")
                progress.update("gate1_validation", gate1_round / GATE1_MAX_ITERATIONS,
                                f"Gate 1 round {gate1_round}: fixing layout issues...")

                # Build refinement prompt — include structural audit errors
                issues = []

                # Structural audit errors (highest priority)
                for err in structural_audit.get("breach_errors", []):
                    issues.append(f"- [STRUCTURAL BREACH] {err}")
                for err in structural_audit.get("manifold_errors", []):
                    issues.append(f"- [NON-MANIFOLD] {err}")

                # Gate checklist issues
                for c in gate1_result.get("checklist", []):
                    if c.get("status") in ("fail", "warning"):
                        issues.append(
                            f"- [{c.get('severity', 'major').upper()}] {c['category']}: "
                            f"{c['description']} Suggestion: {c.get('suggestion', 'N/A')}"
                        )

                # Mandatory fixes from Gemini
                for fix in gate1_result.get("mandatory_fixes", []):
                    issues.append(f"- [MANDATORY] {fix}")

                if issues:
                    refinement_prompt = (
                        f"Gate 1 validation scored {gate1_score}/10. "
                        f"Structural clearance: {structural_clearance}.\n"
                        f"You MUST acknowledge each structural error and fix it:\n"
                        + "\n".join(issues)
                    )
                    robot_spec = await _refine_spec(robot_spec, refinement_prompt)
                    results["robot_spec"] = robot_spec.model_dump()
                    spec_path.write_text(robot_spec.model_dump_json(indent=2))
                else:
                    break
            else:
                progress.update("gate1_validation", 1.0, "Gate 1 skipped (no job dir)")
                break
        except Exception as e:
            logger.warning(f"Gate 1 validation failed: {e}")
            results["errors"].append(f"Gate 1: {e}")
            progress.update("gate1_validation", 1.0, f"Gate 1 skipped: {e}")
            break

    # Step 3: Submit to Simulation Server
    progress.update("simulation", 0.0, "Submitting to simulation server...")
    sim_client = SimulationClient()
    job_id = str(uuid.uuid4())
    feedback = None
    try:

        submit_result = await sim_client.submit_simulation(
            job_id=job_id,
            robot_spec=robot_spec,
            simulation_type="full",
        )
        results["simulation_job_id"] = job_id
        progress.update("simulation", 0.5, f"Simulation submitted: {job_id}")

        # Poll for completion
        feedback = await sim_client.wait_for_feedback(job_id, timeout=300)
        if feedback:
            results["simulation_feedback"] = feedback
            progress.update("simulation", 1.0, "Simulation complete")

            # Save feedback
            feedback_path = project_dir / "simulation_feedback.json"
            feedback_path.write_text(json.dumps(feedback, indent=2))

            # Save job ID for later retrieval
            job_id_path = project_dir / "simulation_job_id.txt"
            job_id_path.write_text(job_id)

    except Exception as e:
        logger.warning(f"Simulation failed: {e}")
        results["errors"].append(f"Simulation: {e}")
        progress.update("simulation", 1.0, f"Simulation skipped: {e}")
        feedback = None

    # Step 4: Webots physics simulation (best-effort)
    progress.update("webots_simulation", 0.0, "Starting Webots physics simulation...")
    try:
        webots_result = await sim_client.start_webots(job_id, convert_urdf=True)
        results["webots"] = webots_result
        progress.update("webots_simulation", 0.5, "Webots simulation running...")

        # Wait for simulation to run briefly (30s), then stop
        await asyncio.sleep(30)

        webots_status = await sim_client.get_webots_status()
        results["webots_status"] = webots_status

        await sim_client.stop_webots()
        progress.update("webots_simulation", 1.0, "Webots simulation complete")
    except Exception as e:
        logger.warning(f"Webots simulation skipped: {e}")
        results["errors"].append(f"Webots: {e}")
        progress.update("webots_simulation", 1.0, f"Webots skipped: {e}")

    # Step 5: Iterative refinement
    MAX_REFINEMENT_ITERATIONS = int(os.getenv("MAX_REFINEMENT_ITERATIONS", "2"))
    refinement_round = 0
    refinement_history = []

    while (
        feedback
        and refinement_round < MAX_REFINEMENT_ITERATIONS
        and _needs_refinement(feedback)
    ):
        refinement_round += 1
        progress.update(
            "refinement",
            refinement_round / MAX_REFINEMENT_ITERATIONS,
            f"Refinement round {refinement_round}..."
        )

        try:
            # Build refinement prompt from feedback
            refinement_prompt = _build_refinement_prompt(robot_spec, feedback)

            # Ask LLM to fix the issues
            refined_spec = await _refine_spec(robot_spec, refinement_prompt)

            # Re-run simulation with refined spec
            robot_spec = refined_spec
            results["robot_spec"] = robot_spec.model_dump()

            # Save updated spec
            spec_path = project_dir / "robot_spec.json"
            spec_path.write_text(robot_spec.model_dump_json(indent=2))

            # Re-generate SCAD for changed parts
            for part in robot_spec.parts:
                if not part.scad_code or not part.scad_code.strip():
                    try:
                        scad_code = await generate_scad_for_part(part, robot_spec.printer)
                        part.scad_code = scad_code
                        scad_path = scad_dir / f"{part.id}.scad"
                        scad_path.write_text(scad_code)
                    except Exception as e:
                        logger.warning(f"Refinement SCAD gen failed for {part.id}: {e}")

            # Re-submit to simulation
            new_job_id = str(uuid.uuid4())
            await sim_client.submit_simulation(
                job_id=new_job_id,
                robot_spec=robot_spec,
                simulation_type="full",
            )
            feedback = await sim_client.wait_for_feedback(new_job_id, timeout=300)
            if feedback:
                results["simulation_feedback"] = feedback
                results["simulation_job_id"] = new_job_id
                # Update saved job ID
                job_id_path = project_dir / "simulation_job_id.txt"
                job_id_path.write_text(new_job_id)
                refinement_history.append({
                    "round": refinement_round,
                    "job_id": new_job_id,
                    "score": feedback.get("overall_score", 0),
                })

        except Exception as e:
            logger.warning(f"Refinement round {refinement_round} failed: {e}")
            results["errors"].append(f"Refinement {refinement_round}: {e}")
            break

    results["refinement_history"] = refinement_history

    # Gate 2: Printability & Aesthetics Validation (refined model)
    GATE2_MAX_ITERATIONS = int(os.getenv("GATE2_MAX_ITERATIONS", "2"))
    gate2_round = 0
    progress.update("gate2_validation", 0.0, "Gate 2: Validating printability & aesthetics...")

    final_job_id = results.get("simulation_job_id")
    if final_job_id:
        while gate2_round < GATE2_MAX_ITERATIONS:
            try:
                job_dir_g2 = config.SIM_JOBS_DIR / final_job_id if hasattr(config, "SIM_JOBS_DIR") else None
                if not job_dir_g2 or not job_dir_g2.exists():
                    break

                gate2_result = await run_visual_validation(
                    project_dir=project_dir,
                    job_dir=job_dir_g2,
                    cad_dir=scad_dir.parent,
                    model_name=robot_spec.name,
                )
                gate2_score = gate2_result.get("visual_quality_score", 0)
                results["gate2_validation"] = gate2_result

                if gate2_score >= 8:
                    progress.update("gate2_validation", 1.0,
                                    f"Gate 2 PASSED (score: {gate2_score}/10)")
                    break

                gate2_round += 1
                logger.info(f"Gate 2 round {gate2_round}: score={gate2_score}/10, iterating...")
                progress.update("gate2_validation", gate2_round / GATE2_MAX_ITERATIONS,
                                f"Gate 2 round {gate2_round}: fixing aesthetics/printability...")

                # Refine based on Gate 2 feedback
                issues = [
                    f"- [{c.get('severity', 'major').upper()}] {c['category']}: {c['description']} "
                    f"Suggestion: {c.get('suggestion', 'N/A')}"
                    for c in gate2_result.get("checklist", [])
                    if c.get("status") in ("fail", "warning")
                ]
                mandatory = gate2_result.get("mandatory_fixes", [])
                if mandatory:
                    issues = [f"- [MANDATORY] {fix}" for fix in mandatory] + issues
                if issues:
                    refinement_prompt = (
                        f"Gate 2 (printability/aesthetics) scored {gate2_score}/10. "
                        f"Fix these issues:\n" + "\n".join(issues)
                    )
                    robot_spec = await _refine_spec(robot_spec, refinement_prompt)
                    results["robot_spec"] = robot_spec.model_dump()
                    spec_path.write_text(robot_spec.model_dump_json(indent=2))

                    # Re-submit for new renders
                    new_job_id = str(uuid.uuid4())
                    await sim_client.submit_simulation(
                        job_id=new_job_id, robot_spec=robot_spec, simulation_type="full",
                    )
                    new_feedback = await sim_client.wait_for_feedback(new_job_id, timeout=300)
                    if new_feedback:
                        results["simulation_feedback"] = new_feedback
                        results["simulation_job_id"] = new_job_id
                        final_job_id = new_job_id
                else:
                    break
            except Exception as e:
                logger.warning(f"Gate 2 validation failed: {e}")
                results["errors"].append(f"Gate 2: {e}")
                break

    # Step 6: Pro Rendering (Blender Cycles — box art quality)
    if final_job_id:
        progress.update("pro_render", 0.0, "Generating pro renders (Blender Cycles)...")
        try:
            job_dir_render = config.SIM_JOBS_DIR / final_job_id if hasattr(config, "SIM_JOBS_DIR") else None
            if job_dir_render and job_dir_render.exists():
                pro_renders = await render_pro_shots(
                    job_dir=job_dir_render,
                    presets=["hero", "transparent"],
                )
                results["pro_renders"] = {k: str(v) for k, v in pro_renders.items()}
                progress.update("pro_render", 1.0,
                                f"Pro renders complete: {len(pro_renders)} images")
            else:
                progress.update("pro_render", 1.0, "Pro render skipped (no job dir)")
        except Exception as e:
            logger.warning(f"Pro rendering skipped: {e}")
            results["errors"].append(f"Pro render: {e}")
            progress.update("pro_render", 1.0, f"Pro render skipped: {e}")

    progress.update("complete", 1.0, "Pipeline complete")
    return results
