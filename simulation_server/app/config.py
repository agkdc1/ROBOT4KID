"""Simulation server configuration."""

import os
from pathlib import Path

# Base paths
BASE_DIR = Path(__file__).resolve().parent.parent
JOBS_DIR = BASE_DIR / "jobs"
JOBS_DIR.mkdir(exist_ok=True)

# OpenSCAD
OPENSCAD_BIN = os.getenv("OPENSCAD_BIN", "openscad")
OPENSCAD_TIMEOUT = int(os.getenv("OPENSCAD_TIMEOUT", "120"))
USE_XVFB = os.getenv("USE_XVFB", "true").lower() == "true"

# Server
HOST = os.getenv("SIM_HOST", "0.0.0.0")
PORT = int(os.getenv("SIM_PORT", "8100"))

# Limits
MAX_CONCURRENT_JOBS = int(os.getenv("MAX_CONCURRENT_JOBS", "3"))
MAX_STL_SIZE_MB = int(os.getenv("MAX_STL_SIZE_MB", "50"))
