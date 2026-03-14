# NL2Bot — Project Conventions

## Project Status
- **Phase 0 (Bootstrap)**: COMPLETE — directory structure, shared schemas, JSON schema export, Python venvs
- **Phase 1 (Simulation Server MVP)**: COMPLETE — FastAPI skeleton, OpenSCAD renderer, STL analyzer, printability checker, URDF generator, Three.js viewer, full /simulate endpoint
- **Phase 2 (Planning Server MVP)**: COMPLETE — FastAPI skeleton, JWT auth, user registration + admin approval, project CRUD, Claude API integration (NLP, CAD gen, firmware gen, app gen), pipeline orchestrator, HTMX web UI
- **Phase 3 (M1A1 Test Case)**: PARTIAL — hull.scad, turret_body.scad, gun_barrel.scad, m4_hardware.scad, common.scad written. Needs more sub-components.
- **Phase 4 (Embedded Firmware)**: COMPLETE — PlatformIO dual-env, hull_node + turret_node firmware, shared protocol, config
- **Phase 5 (Flutter Control App)**: COMPLETE — dual joystick, HUD overlay, button panel, WebSocket connection service, command protocol
- **Phase 6-7**: NOT STARTED — ballistics/edge AI, integration, docker compose testing

## Next Steps (Continue on Windows 11 + WSL2 + RTX 3060)
1. Clone repo into WSL2: `git clone git@github.com:agkdc1/ROBOT4KID.git ~/ROBOT4KID`
2. Run `system/setup_ubuntu.sh` to install dependencies and create venvs
3. Run `system/setup_gpu.sh` for CUDA/PyTorch on RTX 3060
4. Set `.env` with your `ANTHROPIC_API_KEY` and a proper `JWT_SECRET_KEY`
5. Start both servers and test end-to-end
6. Complete remaining Phase 3 OpenSCAD parts (track_assembly, battery_compartment, motor_mount, etc.)
7. Test full pipeline: NL prompt → Claude generates RobotSpec → SCAD rendering → URDF assembly → 3D viewer
8. PyBullet physics integration (install pybullet in sim server venv)

## Architecture
- **Two-server architecture**: Planning Server (port 8000) + Simulation Server (port 8100)
- **Shared schemas**: All data contracts live in `shared/schemas/` as Pydantic models
- **The Simulation Server is standalone**: It knows nothing about Claude, users, or conversations. It accepts a `SimulationRequest` JSON and returns `SimulationFeedback`.

## Running the Servers
```bash
# Set environment (copy .env.example to .env first)
cp system/.env.example .env
# Edit .env with your ANTHROPIC_API_KEY

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

## Design Rules (Bambu A1 Mini)
- Build volume: 180x180x180mm
- Wall thickness: min 1.2mm (3 perimeters)
- M4 holes: 4.4mm diameter
- M4 shafts: 3.8mm diameter
- Print tolerance: 0.2mm
- Max overhang: 45 degrees without supports

## Important Notes
- Keep all project files on Linux filesystem in WSL2 (not /mnt/c/) for performance
- OpenSCAD needs Xvfb for headless rendering: `xvfb-run openscad -o out.stl in.scad`
- RTX 3060 CUDA works natively in WSL2 — no special passthrough needed
- Planning UI is HTMX + Jinja2 + Alpine.js (no separate frontend build step)
- Claude API uses tool_use (function calling) with forced tool choice for structured output

## Testing
```bash
# Simulation server health
curl http://localhost:8100/api/v1/health

# Validate a robot spec
curl -X POST http://localhost:8100/api/v1/validate \
  -H "Content-Type: application/json" \
  -d '{"robot_spec":{"name":"Test","parts":[]}}'

# Planning server auth flow
# 1. Register: POST /api/v1/auth/register {"username":"user","password":"pass123"}
# 2. Admin login: POST /api/v1/auth/login (form: username=admin, password=admin)
# 3. Approve: POST /api/v1/admin/users/{id}/approve (with admin JWT)
# 4. User login → create project → run pipeline
```
