# NL2Bot — Project Conventions

## Project Status
- **Phase 0 (Bootstrap)**: COMPLETE — directory structure, shared schemas, JSON schema export, Python venvs
- **Phase 1 (Simulation Server MVP)**: COMPLETE — FastAPI skeleton, OpenSCAD renderer, STL analyzer, printability checker, URDF generator, Three.js viewer, full /simulate endpoint
- **Phase 2 (Planning Server MVP)**: COMPLETE — FastAPI skeleton, JWT auth, user registration + admin approval, project CRUD, dual LLM integration (Claude primary + Gemini secondary), pipeline orchestrator, HTMX web UI
- **Phase 3 (M1A1 Test Case)**: COMPLETE — hull (front/rear split), turret_body, gun_barrel, track_assembly, electronics_bay, console_cradle. Full sensor integration: dual ESP32-CAM (hull + turret), VL53L1X ToF, MPU-6050 IMU. Solderless design with component mounts, wire ducts, slip-ring void.
- **Phase 4 (Embedded Firmware)**: COMPLETE — PlatformIO dual-env, hull_node + turret_node firmware, shared protocol, config
- **Phase 5 (Flutter Control App)**: COMPLETE — project selection screen, MJPEG camera with PIP toggle, USB gamepad support (2 sticks + 4 buttons), FCS crosshair overlay with barrel angle control, trajectory equation, shot recording for RL training, CI/CD deploy scripts
- **Phase 6 (FCS / Ballistics)**: PARTIAL — trajectory equation with 5 tunable coefficients (gravity, drag, hop-up, motion, bias), server-side gradient descent training endpoint, shot data upload from tablet. Needs: real camera ball tracking, PyTorch RL upgrade, edge AI deployment.
- **Phase 7 (Webots Simulation)**: PARTIAL — Webots world template, tank/supervisor controllers, PROTO converter, WebSocket telemetry bridge, API endpoints. Needs: end-to-end testing, Docker compose, live Three.js viewer mode.
- **Phase 8**: NOT STARTED — full integration, production deployment

## Next Steps
1. Fetch secrets: `./system/fetch_secrets.sh` (or manually set `.env`)
2. Install deps: `cd planning_server && pip install -r requirements.txt`
3. Install Webots (R2023b+) and set `WEBOTS_HOME` env var
4. Start both servers and test end-to-end
5. Run LLM evaluation: `python -m tests.test_llm_pipeline --provider claude --step all`
6. Test Webots simulation: `POST /api/v1/webots/start` with a job ID
7. Test full pipeline: NL prompt → LLM generates RobotSpec → SCAD rendering → URDF → Webots PROTO → simulation

## Architecture
- **Two-server architecture**: Planning Server (port 8000) + Simulation Server (port 8100)
- **Shared schemas**: All data contracts live in `shared/schemas/` as Pydantic models
- **The Simulation Server is standalone**: It knows nothing about LLMs, users, or conversations. It accepts a `SimulationRequest` JSON and returns `SimulationFeedback`.
- **Dual LLM**: Claude Sonnet (primary — 3D modeling, planning, structured generation) + Gemini (secondary — simpler tasks, expansion). Provider abstraction in `planning_server/app/pipeline/llm.py`.
- **Webots Integration**: Physics simulation via Webots. Controllers communicate over TCP (binary protocol port 10200, JSON supervisor port 10201). WebSocket bridge streams telemetry at 30Hz.

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
- CAD source files in `cad/` with hardware libraries in `cad/libs/`
- Webots worlds and controllers in `simulation/`
- ESP32 firmware in `embedded/` (PlatformIO, dual env: hull_node, turret_node)
- Flutter app in `frontend/`
- Terraform infra in `infra/terraform/`
- System scripts in `system/` (setup, backup, restore, secrets)
- Tests and reference specs in `tests/`

## CAD Components
### Libraries (`cad/libs/`)
- `common.scad` — printer constraints, tank dimensions, rounded_cube, shell, split_key/socket
- `m4_hardware.scad` — M4 screw/hole/nut_trap/standoff (hull assembly)
- `m3_hardware.scad` — M3/M2.5 screw/hole/standoff (electronics mounting)
- `electronics.scad` — dummy volumes and mounts for all electronic components

### Chassis (`cad/chassis/`)
- `hull.scad` — front/rear split hull, glacis plate, turret ring, hull camera mount, slip-ring void, electronics bay floor mounts
- `track_assembly.scad` — side plates, road wheels, drive sprocket, idler wheel, N20 motor mount
- `electronics_bay.scad` — removable tray with mounts for ESP32+shield, L298N, LM2596, 18650 battery, WAGO connectors, MPU-6050 IMU, wire ducts, zip-tie anchors

### Turret (`cad/turret/`)
- `turret_body.scad` — turret shell, ring, gun trunnion, turret ESP32-CAM mount, VL53L1X mount, slip-ring void, internal wire duct
- `gun_barrel.scad` — barrel tube, bayonet mount, muzzle brake

### Cockpit (`cad/cockpit/`)
- `console_cradle.scad` — split tablet cradle (Galaxy Tab A 8.0), gamepad dock, cable management

### Assembly
- `assembly.scad` — full tank visualization with all components and dummy volumes

## Electronics (Solderless Design)
All connections use Dupont jumpers and screw terminals. 20mm vertical clearance above all pin headers.

| Component | Dimensions (mm) | Mounting | Location |
|-----------|-----------------|----------|----------|
| ESP32 DevKitC V4 | 55x28x13 | On Terminal Shield | Electronics bay |
| Terminal Block Shield | 85x65x20 | 4x M3 standoffs (76x56mm) | Electronics bay |
| ESP32-CAM (hull) | 40x27x12 | Cradle mount | Hull front |
| ESP32-CAM (turret) | 40x27x12 | Cradle mount | Turret, co-axial with gun |
| L298N Motor Driver | 43x43x27 | 4x M3 standoffs (36x36mm) | Electronics bay |
| LM2596 Buck Converter | 43x21x14 | 2x M3 standoffs | Electronics bay |
| 18650 Battery Holder (2S) | 77x41x20 | Friction-fit cradle | Electronics bay |
| MPU-6050 IMU | 21x16x3 | 2x M2.5 standoffs | Electronics bay center |
| VL53L1X ToF | 13x18x4 | Rail cradle | Turret, below camera |
| WAGO 221-415 (x3) | 20x13x16 | Snap-in holders | Electronics bay |
| N20 Motor (x2) | 12dia x 25 | Clamp cradle | Track assembly |

## Webots Simulation
- **World**: `simulation/worlds/flat_ground.wbt` — 10x10m arena with tank robot
- **Tank Controller**: `simulation/controllers/tank_controller/` — TCP port 10200, binary TankCommand protocol (matches ESP32 firmware)
- **Supervisor**: `simulation/controllers/supervisor_controller/` — TCP port 10201, JSON telemetry streaming at 30Hz
- **PROTO Converter**: `simulation_server/app/simulator/proto_converter.py` — URDF → Webots .proto conversion
- **Webots Manager**: `simulation_server/app/simulator/webots_manager.py` — process lifecycle (headless `--no-rendering`)
- **WebSocket Bridge**: `simulation_server/app/simulator/webots_bridge.py` — async telemetry streaming

### Webots API Endpoints
- `POST /api/v1/webots/start` — start simulation for a job
- `POST /api/v1/webots/stop` — stop simulation
- `GET /api/v1/webots/status` — simulation status
- `POST /api/v1/webots/command` — send tank command
- `WebSocket /api/v1/webots/{job_id}/ws` — live telemetry stream

## LLM Provider Configuration
- **Claude** (primary): `ANTHROPIC_API_KEY`, models: `claude-sonnet-4-6-20250514` (fast), `claude-opus-4-6-20250514` (smart)
- **Gemini** (secondary): `GEMINI_API_KEY`, model: `gemini-2.5-flash`
- All pipeline modules accept a `provider` parameter: `Provider.CLAUDE` or `Provider.GEMINI`
- Provider abstraction: `planning_server/app/pipeline/llm.py` — `generate_text()` and `generate_with_tool()`

## Cockpit / Control App
- **Tablet**: Galaxy Tab A 8.0 2019 (USB Type-C, configurable in settings)
- **Joystick**: USB HID gamepad — 2 analog sticks + 4 buttons (A=fire, B=view toggle, X=FCS toggle, Y=spare)
- **Camera**: Chassis camera = main view, turret camera = PIP. Press VIEW to swap.
- **FCS**: Crosshair centered on turret view, movable in middle 1/3 vertically. Barrel angle adjusts with crosshair. FCS computes trajectory based on range, ball speed, hop-up, chassis speed, turret angle.
- **Trajectory Equation**: `angle = gravity_comp + drag_comp - hopup_comp + motion_comp + bias` (5 tunable coefficients)
- **RL Training**: Shot data uploaded to server every 5 shots. Server runs gradient descent on coefficients. Updated coefficients deployed back to tablet.
- **Deploy**: `.\system\deploy_app.ps1` (Windows) or `./system/deploy_app.sh` (bash). Builds APK and installs via ADB.

## FCS API Endpoints
- `GET /api/v1/fcs/coefficients` — current trajectory coefficients
- `POST /api/v1/fcs/shots` — upload shot records
- `POST /api/v1/fcs/train` — trigger RL training
- `DELETE /api/v1/fcs/shots` — clear shot buffer

## Design Rules (Bambu A1 Mini)
- Build volume: 180x180x180mm
- Wall thickness: min 1.2mm (3 perimeters)
- M4 holes: 4.4mm diameter, M3 holes: 3.4mm diameter
- M4 shafts: 3.8mm diameter
- Print tolerance: 0.2mm
- Max overhang: 45 degrees without supports
- Wiring clearance: 20mm above pin headers/terminals (Dupont connectors)

## Important Notes
- Secrets stored in GCP Secret Manager — never commit API keys to git
- `.env`, `*.tfstate`, `*.tfvars`, credentials files are all gitignored
- Use `gcloud.cmd` (not `gcloud`) on Windows for shell commands
- OpenSCAD needs Xvfb for headless rendering: `xvfb-run openscad -o out.stl in.scad`
- Planning UI is HTMX + Jinja2 + Alpine.js (no separate frontend build step)
- Claude API uses tool_use (function calling) with forced tool choice for structured output
- Gemini uses JSON response mode for structured output
- Webots requires R2023b+ and `WEBOTS_HOME` env var for headless operation

## Testing
```bash
# Simulation server health
curl http://localhost:8100/api/v1/health

# Run LLM pipeline evaluation
python -m tests.test_llm_pipeline --provider claude --step all
python -m tests.test_llm_pipeline --provider gemini --step nlp

# Start Webots simulation
curl -X POST http://localhost:8100/api/v1/webots/start -H "Content-Type: application/json" -d '{"job_id":"test"}'

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
