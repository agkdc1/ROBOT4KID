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
from planning_server.app.pipeline.reference_search import search_and_analyze
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

    progress.update("complete", 1.0, "Pipeline complete")
    return results
