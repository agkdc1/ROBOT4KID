#!/usr/bin/env python3
"""Export hardware_specs.yaml as JSON for OpenSCAD consumption.

Usage: python config/export_scad_params.py
Output: config/hardware_specs.json (importable via OpenSCAD's `include`)
"""

import json
from pathlib import Path
import yaml

config_dir = Path(__file__).parent
yaml_path = config_dir / "hardware_specs.yaml"
json_path = config_dir / "hardware_specs.json"

with open(yaml_path) as f:
    data = yaml.safe_load(f)

with open(json_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"Exported {json_path}")
