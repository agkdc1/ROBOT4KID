#!/usr/bin/env python3
"""Export Pydantic models to JSON Schema files for use in Claude prompts."""

import json
import sys
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from shared.schemas.robot_spec import RobotSpec
from shared.schemas.simulation_request import SimulationRequest
from shared.schemas.simulation_feedback import SimulationFeedback

OUTPUT_DIR = Path(__file__).parent / "json_schemas"
OUTPUT_DIR.mkdir(exist_ok=True)

schemas = {
    "robot_spec.schema.json": RobotSpec,
    "simulation_request.schema.json": SimulationRequest,
    "simulation_feedback.schema.json": SimulationFeedback,
}

for filename, model in schemas.items():
    schema = model.model_json_schema()
    output_path = OUTPUT_DIR / filename
    output_path.write_text(json.dumps(schema, indent=2))
    print(f"Exported: {output_path}")

print(f"\nAll schemas exported to {OUTPUT_DIR}")
