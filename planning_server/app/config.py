"""Planning server configuration."""

import os
from pathlib import Path

# Base paths
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)
PROJECTS_DIR = DATA_DIR / "projects"
PROJECTS_DIR.mkdir(exist_ok=True)

# Database
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite+aiosqlite:///{DATA_DIR / 'db.sqlite3'}")

# Server
HOST = os.getenv("PLAN_HOST", "0.0.0.0")
PORT = int(os.getenv("PLAN_PORT", "8000"))

# Claude API (primary — 3D modeling, planning, complex generation)
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
CLAUDE_MODEL_FAST = os.getenv("CLAUDE_MODEL_FAST", "claude-sonnet-4-6-20250514")
CLAUDE_MODEL_SMART = os.getenv("CLAUDE_MODEL_SMART", "claude-opus-4-6-20250514")
CLAUDE_MAX_RETRIES = int(os.getenv("CLAUDE_MAX_RETRIES", "3"))

# Gemini API (secondary — simpler tasks, expansion)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

# GCP
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID", "")

# Simulation Server
SIMULATION_SERVER_URL = os.getenv("SIMULATION_SERVER_URL", "http://localhost:8100")

# Auth
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "CHANGE-ME-IN-PRODUCTION-use-openssl-rand-hex-32")
JWT_ALGORITHM = "HS256"
JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 60
JWT_REFRESH_TOKEN_EXPIRE_DAYS = 7

# Admin
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin")
