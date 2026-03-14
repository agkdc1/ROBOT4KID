"""Pipeline orchestrator — sequences pipeline steps with progress reporting."""

import json
import logging
import uuid
from pathlib import Path

from planning_server.app import config
from planning_server.app.pipeline.llm import Provider
from planning_server.app.pipeline.nlp import parse_nl_to_robot_spec
from planning_server.app.pipeline.cad_gen import generate_scad_for_part
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
        "robot_spec": None,
        "simulation_job_id": None,
        "simulation_feedback": None,
        "errors": [],
    }

    # Step 1: NLP Parse
    progress.update("nlp_parse", 0.0, "Parsing natural language description...")
    try:
        robot_spec = await parse_nl_to_robot_spec(prompt)
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
    try:
        sim_client = SimulationClient()
        job_id = str(uuid.uuid4())

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

    except Exception as e:
        logger.warning(f"Simulation failed: {e}")
        results["errors"].append(f"Simulation: {e}")
        progress.update("simulation", 1.0, f"Simulation skipped: {e}")

    progress.update("complete", 1.0, "Pipeline complete")
    return results
