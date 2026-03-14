# NL2Bot — Project Conventions

## Project Status
- **Phase 0 (Bootstrap)**: COMPLETE — directory structure, shared schemas, JSON schema export, Python venvs
- **Phase 1 (Simulation Server MVP)**: COMPLETE — FastAPI skeleton, OpenSCAD renderer, STL analyzer, printability checker, URDF generator, Three.js viewer, full /simulate endpoint
- **Phase 2 (Planning Server MVP)**: COMPLETE — FastAPI skeleton, JWT auth, user registration + admin approval, project CRUD, dual LLM integration (Claude primary + Gemini secondary), pipeline orchestrator, HTMX web UI
- **Phase 3 (M1A1 Test Case)**: PARTIAL — hull.scad, turret_body.scad, gun_barrel.scad, m4_hardware.scad, common.scad written. Reference spec and test/eval script created. Needs remaining sub-components (track_assembly, battery_compartment, motor_mount, servo_mount, electronics_bay).
- **Phase 4 (Embedded Firmware)**: COMPLETE — PlatformIO dual-env, hull_node + turret_node firmware, shared protocol, config
- **Phase 5 (Flutter Control App)**: COMPLETE — dual joystick, HUD overlay, button panel, WebSocket connection service, command protocol
- **Phase 6-7**: NOT STARTED — ballistics/edge AI, integration, docker compose testing

## Next Steps
1. Fetch secrets: `./system/fetch_secrets.sh` (or manually set `.env`)
2. Install planning server deps: `cd planning_server && pip install -r requirements.txt`
3. Start both servers and test end-to-end
4. Run LLM evaluation: `python -m tests.test_llm_pipeline --provider claude --step all`
5. Complete remaining Phase 3 OpenSCAD parts
6. Test full pipeline: NL prompt → LLM generates RobotSpec → SCAD rendering → URDF assembly → 3D viewer
7. PyBullet physics integration (install pybullet in sim server venv)

## Architecture
- **Two-server architecture**: Planning Server (port 8000) + Simulation Server (port 8100)
- **Shared schemas**: All data contracts live in `shared/schemas/` as Pydantic models
- **The Simulation Server is standalone**: It knows nothing about LLMs, users, or conversations. It accepts a `SimulationRequest` JSON and returns `SimulationFeedback`.
- **Dual LLM**: Claude Sonnet (primary — 3D modeling, planning, structured generation) + Gemini (secondary — simpler tasks, expansion). Provider abstraction in `planning_server/app/pipeline/llm.py`.

## GCP Infrastructure
- **Project**: `nl2bot-f7e604` (account: ahnchoonghyun@gmail.com)
- **Backup Bucket**: `nl2bot-f7e604-backup` (us-west1, free tier)
- **Secrets**: `anthropic-api-key`, `gemini-api-key`, `jwt-secret-key` in Secret Manager
- **Terraform**: `infra/terraform/` — manages project, APIs, bucket, secrets
- **Backup/Restore**: `system/backup.sh`, `system/restore.sh`, `system/fetch_secrets.sh`

## Running the Servers
```bash
# Fetch secrets from GCP (creates .env automatically)
./system/fetch_secrets.sh

# Or manually: copy .env.example to .env and fill in keys

# Planning server
cd planning_server && .venv/bin/python -m uvicorn app.main:app --port 8000 --reload

# Simulation server (separate terminal)
cd simulation_server && .venv/bin/python -m uvicorn app.main:app --port 8100 --reload
```

## Default Admin
- Username: `admin`, Password: `admin` (auto-created on first boot)
- Change via ADMIN_USERNAME/ADMIN_PASSWORD env vars

## Code Style
- Python: Follow PEP 8. Use type hints. Pydantic v2 for all schemas.
- OpenSCAD: Variables at top, modules below, `$fn=64` for curves, all dimensions in mm.
- C++ (ESP32): Arduino framework, PlatformIO conventions. Shared protocol in `embedded/lib/shared/`.
- Flutter/Dart: Provider for state management, Material 3 theme.

## Key Schemas
- `RobotSpec` — master specification (the single source of truth)
- `SimulationRequest` — sent from Planning to Simulation server
- `SimulationFeedback` — returned by Simulation server
- All schemas are in `shared/schemas/`. JSON Schema exports in `shared/json_schemas/`.

## File Organization
- Generated files go to `planning_server/data/projects/{project_id}/`
- Simulation jobs go to `simulation_server/jobs/{job_id}/`
- CAD source files in `cad/` with M4 hardware library in `cad/libs/`
- ESP32 firmware in `embedded/` (PlatformIO, dual env: hull_node, turret_node)
- Flutter app in `frontend/`
- Terraform infra in `infra/terraform/`
- System scripts in `system/` (setup, backup, restore, secrets)
- Tests and reference specs in `tests/`

## LLM Provider Configuration
- **Claude** (primary): `ANTHROPIC_API_KEY`, models: `claude-sonnet-4-6-20250514` (fast), `claude-opus-4-6-20250514` (smart)
- **Gemini** (secondary): `GEMINI_API_KEY`, model: `gemini-2.5-flash`
- All pipeline modules accept a `provider` parameter: `Provider.CLAUDE` or `Provider.GEMINI`
- Provider abstraction: `planning_server/app/pipeline/llm.py` — `generate_text()` and `generate_with_tool()`

## Design Rules (Bambu A1 Mini)
- Build volume: 180x180x180mm
- Wall thickness: min 1.2mm (3 perimeters)
- M4 holes: 4.4mm diameter
- M4 shafts: 3.8mm diameter
- Print tolerance: 0.2mm
- Max overhang: 45 degrees without supports

## Important Notes
- Secrets stored in GCP Secret Manager — never commit API keys to git
- `.env`, `*.tfstate`, `*.tfvars`, credentials files are all gitignored
- Use `gcloud.cmd` (not `gcloud`) on Windows for shell commands
- OpenSCAD needs Xvfb for headless rendering: `xvfb-run openscad -o out.stl in.scad`
- Planning UI is HTMX + Jinja2 + Alpine.js (no separate frontend build step)
- Claude API uses tool_use (function calling) with forced tool choice for structured output
- Gemini uses JSON response mode for structured output

## Testing
```bash
# Simulation server health
curl http://localhost:8100/api/v1/health

# Run LLM pipeline evaluation
python -m tests.test_llm_pipeline --provider claude --step all
python -m tests.test_llm_pipeline --provider gemini --step nlp

# Planning server auth flow
# 1. Register: POST /api/v1/auth/register {"username":"user","password":"pass123"}
# 2. Admin login: POST /api/v1/auth/login (form: username=admin, password=admin)
# 3. Approve: POST /api/v1/admin/users/{id}/approve (with admin JWT)
# 4. User login → create project → run pipeline

# Backup/Restore
./system/backup.sh v1.0
./system/restore.sh v1.0
./system/restore.sh --list
```
