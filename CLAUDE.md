# NL2Bot — Project Conventions

## Project Status
- **Phase 0 (Bootstrap)**: COMPLETE — directory structure, shared schemas, JSON schema export, Python venvs
- **Phase 1 (Simulation Server MVP)**: COMPLETE — FastAPI skeleton, OpenSCAD renderer, STL analyzer, printability checker, URDF generator, Three.js viewer, full /simulate endpoint
- **Phase 2 (Planning Server MVP)**: COMPLETE — FastAPI skeleton, JWT auth, user registration + admin approval, project CRUD, dual LLM integration (Claude primary + Gemini secondary), pipeline orchestrator, HTMX web UI
- **Phase 3 (M1A1 Test Case)**: COMPLETE — hull (front/rear split), turret_body, gun_barrel, track_assembly, electronics_bay, console_cradle. Full sensor integration: dual ESP32-CAM (hull + turret), VL53L1X ToF, MPU-6050 IMU. Solderless design with component mounts, wire ducts, slip-ring void.
- **Phase 4 (Embedded Firmware)**: COMPLETE — PlatformIO dual-env, hull_node + turret_node firmware, shared protocol, config
- **Phase 5 (Flutter Control App)**: COMPLETE — project selection screen, MJPEG camera with PIP toggle, USB gamepad support (2 sticks + 4 buttons), FCS crosshair overlay with barrel angle control, trajectory equation, shot recording for RL training, CI/CD deploy scripts
- **Phase 6 (FCS / Ballistics)**: PARTIAL — trajectory equation with 5 tunable coefficients (gravity, drag, hop-up, motion, bias), server-side gradient descent training endpoint, shot data upload from tablet. Needs: real camera ball tracking, PyTorch RL upgrade, edge AI deployment.
- **Phase 7 (Webots Simulation)**: COMPLETE — Webots world template, tank/supervisor controllers, PROTO converter, WebSocket telemetry bridge, API endpoints, pipeline integration (auto-runs after URDF assembly). Needs: end-to-end testing, Docker compose, live Three.js viewer mode.
- **Phase 7.5 (Service Deployment)**: COMPLETE — NSSM Windows services, API key auth for simulation server, dotenv loading, .env.example, PowerShell service management script, iterative refinement loop (simulation feedback → LLM redesign).
- **Phase 9 (Multi-Model Ecosystem)**: COMPLETE — Modular architecture supporting multiple robot types (tank, train). Shinkansen N700 Plarail-compatible train with ESP32-CAM. RPi4 console with 7" display + PS2 joystick. Universal command schema. Unified Flutter app with model-type routing. YAML-driven hardware config.
- **Phase 10 (Cloudflare Access)**: PARTIAL — Access setup script (`system/setup_cloudflare_access.sh`) using Cloudflare API, email OTP policy, tunnel config with originRequest. Needs: run script with real API token, add IdP (GitHub/Google), integration testing.
- **Phase 11 (Management Dashboard)**: COMPLETE — React 19 + Vite + Tailwind v4 dashboard with military command-center aesthetic. Infrastructure monitor (CPU/RAM/GPU/disk, server health, Windows services), task manager (simulation jobs, system logs), project viewer (model registry grid). TanStack Query for real-time polling. Backend API endpoints in Planning Server (`/api/v1/dashboard/*`).

## Next Steps
1. Configure `.env` (copy from `.env.example` or fetch from GCP: `./system/fetch_secrets.sh`)
2. Install services: `.\system\services.ps1 install` (requires admin)
3. Start services: `.\system\services.ps1 start`
4. Install Webots (R2023b+) and set `WEBOTS_HOME` env var
5. Run LLM evaluation: `python -m tests.test_llm_pipeline --provider claude --step all`
6. Test full pipeline: NL prompt → RobotSpec → SCAD → STL → URDF → Webots PROTO → simulation → refinement

## Architecture
- **Two-server architecture**: Planning Server (port 8000) + Simulation Server (port 8100)
- **Multi-model ecosystem**: Tank (differential drive, dual camera, FCS) + Train (simple speed, single camera). Extensible via `ModelType` enum.
- **Shared schemas**: All data contracts live in `shared/schemas/` as Pydantic models. `UniversalCommand` supports both drive modes.
- **Hardware config as YAML**: All dimensions, speeds, pin mappings in `config/hardware_specs.yaml` — single source of truth. Python loader: `shared/hardware_config.py`.
- **The Simulation Server is standalone**: It knows nothing about LLMs, users, or conversations. It accepts a `SimulationRequest` JSON and returns `SimulationFeedback`.
- **Dual LLM**: Claude Sonnet (primary — 3D modeling, planning, structured generation) + Gemini (secondary — simpler tasks, expansion). Provider abstraction in `planning_server/app/pipeline/llm.py`.
- **Webots Integration**: Physics simulation via Webots. Controllers communicate over TCP (binary protocol port 10200, JSON supervisor port 10201). WebSocket bridge streams telemetry at 30Hz.
- **Service Deployment**: NSSM Windows services, Cloudflare Tunnel for external HTTPS access, VS Code tunnel for remote dev, API key auth for inter-service communication.
- **Iterative Refinement**: Simulation feedback is sent back to the LLM to fix design issues (max 2 rounds by default). Controlled by `MAX_REFINEMENT_ITERATIONS` env var.
- **Management Dashboard**: React 19 SPA (`dashboard/`) on port 3000. Proxies to Planning Server (8000) and Simulation Server (8100). Uses TanStack Query for real-time polling (5s intervals). Dashboard API in `planning_server/app/dashboard/router.py`.

## GCP Infrastructure
- **Project**: `nl2bot-f7e604` (account: ahnchoonghyun@gmail.com)
- **Backup Bucket**: `nl2bot-f7e604-backup` (us-west1, free tier)
- **Secrets**: `anthropic-api-key`, `gemini-api-key`, `jwt-secret-key`, `sim-api-key`, `nl2bot-admin-password`, `nl2bot-domains` in Secret Manager
- **Terraform**: `infra/terraform/` — manages project, APIs, bucket, secrets
- **Backup/Restore**: `system/backup.sh`, `system/restore.sh`, `system/fetch_secrets.sh`

## Cloudflare Access
- **Setup script**: `system/setup_cloudflare_access.sh` — creates Access apps + email-allow policies via Cloudflare API
- **Tunnel config**: `~/.cloudflared/config.yml` — routes custom domains to localhost (domains stored in GCP SM `nl2bot-domains`)
- **Tunnel service**: `NL2Bot-Tunnel` (NSSM Windows service, auto-start)
- **Auth flow**: User visits custom domain -> Cloudflare Access login (email OTP) -> tunnel -> localhost
- **Dashboard**: Manage apps/policies at `https://one.dash.cloudflare.com/<account-id>/access/apps`

### Cloudflare Access Setup
```bash
# Set credentials
export CF_API_TOKEN="your-token"    # Create at https://dash.cloudflare.com/profile/api-tokens
export CF_ACCOUNT_ID="your-id"      # Dashboard sidebar -> Account ID

# Dry run first
./system/setup_cloudflare_access.sh --dry-run

# Create Access apps + policies
./system/setup_cloudflare_access.sh --allowed-emails your@email.com

# Store account ID in GCP Secret Manager
./system/setup_cloudflare_access.sh --store-secret

# Remove Access apps
./system/setup_cloudflare_access.sh --delete
```

## Running the Servers

### As Windows Services (recommended)
```powershell
# Install and start all services (Planning, Simulation, Cloudflare Tunnel)
.\system\services.ps1 install
.\system\services.ps1 start

# Check status
.\system\services.ps1 status

# View logs
.\system\services.ps1 logs
```

### Manual (development)
```bash
# Fetch secrets from GCP (creates .env automatically)
./system/fetch_secrets.sh

# Or manually: copy .env.example to .env and fill in keys

# Planning server
cd planning_server && .venv/bin/python -m uvicorn app.main:app --port 8000 --reload

# Simulation server (separate terminal)
cd simulation_server && .venv/bin/python -m uvicorn app.main:app --port 8100 --reload

# Management dashboard (separate terminal)
cd dashboard && npm run dev   # http://localhost:3000
```

## Default Admin
- Username: `admin`, Password: `admin` (auto-created on first boot)
- Change via ADMIN_USERNAME/ADMIN_PASSWORD env vars

## Code Style
- Python: Follow PEP 8. Use type hints. Pydantic v2 for all schemas.
- OpenSCAD: Variables at top, modules below, `$fn=64` for curves, all dimensions in mm. Reference `config/hardware_specs.yaml` for values.
- C++ (ESP32): Arduino framework, PlatformIO conventions. Shared protocol in `embedded/lib/shared/`.
- Flutter/Dart: Provider for state management, Material 3 theme.
- React/TypeScript: Vite + Tailwind v4, path aliases via `@/`, TanStack Query for data fetching.
- **No magic numbers**: All hardware dimensions, speeds, RPMs, pin assignments etc. belong in `config/hardware_specs.yaml`. Python code loads via `shared/hardware_config.py`.

## Key Schemas
- `RobotSpec` — master specification (the single source of truth), includes `model_type` (tank/train)
- `UniversalCommand` — model-agnostic command envelope (differential or simple drive)
- `SimulationRequest` — sent from Planning to Simulation server
- `SimulationFeedback` — returned by Simulation server
- All schemas are in `shared/schemas/`. JSON Schema exports in `shared/json_schemas/`.

## File Organization
- Generated files go to `planning_server/data/projects/{project_id}/`
- Simulation jobs go to `simulation_server/jobs/{job_id}/`
- CAD source files in `cad/` with hardware libraries in `cad/libs/`
- Train CAD in `cad/train/` (locomotive, motor mount, battery bay, camera mount)
- Webots worlds and controllers in `simulation/`
- ESP32 firmware in `embedded/` (PlatformIO, 3 envs: hull_node, turret_node, train_node)
- Flutter app in `frontend/` (unified — auto-switches between tank and train UI)
- RPi4 console controller in `console/` (Python, PS2 joystick, pygame display)
- Hardware specs in `config/hardware_specs.yaml` (single source of truth for all dimensions)
- Terraform infra in `infra/terraform/`
- System scripts in `system/` (setup, backup, restore, secrets)
- Management dashboard in `dashboard/` (Vite + React 19 + Tailwind v4)
- Dashboard backend API in `planning_server/app/dashboard/`
- Tests and reference specs in `tests/`

## CAD Components
### Libraries (`cad/libs/`)
- `common.scad` — printer constraints, tank dimensions, rounded_cube, shell, split_key/socket
- `m4_hardware.scad` — M4 screw/hole/nut_trap/standoff (hull assembly)
- `m3_hardware.scad` — M3/M2.5 screw/hole/standoff (electronics mounting)
- `electronics.scad` — dummy volumes and mounts for all electronic components (19 components)
- `mounts.scad` — universal parametric mount library (cradle, standoff, rail, snap-clip, display frame, angled panel)

### Tank — Chassis (`cad/chassis/`)
- `hull.scad` — front/rear split hull, glacis plate, turret ring, hull camera mount, slip-ring void, electronics bay floor mounts
- `track_assembly.scad` — side plates, road wheels, drive sprocket, idler wheel, N20 motor mount
- `electronics_bay.scad` — removable tray with mounts for ESP32+shield, L298N, LM2596, 18650 battery, WAGO connectors, MPU-6050 IMU, wire ducts, zip-tie anchors

### Tank — Turret (`cad/turret/`)
- `turret_body.scad` — turret shell, ring, gun trunnion, turret ESP32-CAM mount, VL53L1X mount, slip-ring void, internal wire duct
- `gun_barrel.scad` — barrel tube, bayonet mount, muzzle brake

### Train — Shinkansen N700 (`cad/train/`)
- `locomotive.scad` — Plarail-compatible body (top/bottom snap-fit shells), N700 nose cone, internal cavities
- `motor_mount.scad` — N20 motor cradle with axle bearing blocks, DRV8833 cable routing
- `battery_bay.scad` — single 18650 friction-fit cradle with wire routing
- `camera_mount.scad` — ESP32-CAM nose mount with 10° downward tilt, lens aperture

### Consoles (`cad/cockpit/`)
- `console_cradle.scad` — split tablet cradle (Galaxy Tab A 8.0), gamepad dock, GL.iNet router bay, Anker power bank bay, Sabrent USB hub bay, cable management
- `train_console.scad` — RPi4 + 7" display station, PS2 joystick mount, MCP3008 ADC, power bank bay

### Assembly
- `assembly.scad` — full tank visualization with all components and dummy volumes

## Electronics (Solderless Design)
All connections use Dupont jumpers and screw terminals. All dimensions are in `config/hardware_specs.yaml`.

### Tank Components
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

### Tank Console (Network Hub)
| Component | Dimensions (mm) | Mounting | Location |
|-----------|-----------------|----------|----------|
| GL.iNet GL-MT300N-V2 | 58x58x25 | Friction cradle | Console, back-left |
| Anker PowerCore Slim 10000 | 149x68x14 | Friction cradle | Console, front bottom |
| Sabrent HB-UM43 USB Hub | 85x30x15 | Rail mount | Console, back wall |

### Train Components
| Component | Dimensions (mm) | Mounting | Location |
|-----------|-----------------|----------|----------|
| ESP32-CAM | 40x27x12 | Tilted cradle (10° down) | Locomotive nose |
| DRV8833 Motor Driver | 17.8x17.8x4 | 2x M2.5 standoffs | Locomotive rear |
| 18650 Battery (1-cell) | 77x21x20 | Friction-fit cradle | Locomotive center |
| N20 Motor | 12dia x 25 | Clamp cradle | Locomotive rear axle |

### Train Console (RPi4 Station)
| Component | Dimensions (mm) | Mounting | Location |
|-----------|-----------------|----------|----------|
| Raspberry Pi 4B | 85x56x17 | 4x M2.5 standoffs (58x49mm) | Console, behind display |
| 7" RPi Touch Display | 194x110x20 | Display frame + M2.5 | Console, top (tilted 15°) |
| PS2 Joystick Module | 40x40x32 | 4x M3 standoffs | Console, front panel (20° angle) |
| MCP3008 ADC Breakout | 40x20x8 | Rail mount | Console, near joystick |
| Anker PowerCore Slim 10000 | 149x68x14 | Friction cradle | Console, bottom layer |

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

## Control Systems

### Tank Console (Tablet + Gamepad)
- **Tablet**: Galaxy Tab A 8.0 2019 (USB Type-C, configurable in settings)
- **Joystick**: USB HID gamepad — 2 analog sticks + 4 buttons (A=fire, B=view toggle, X=FCS toggle, Y=spare)
- **Camera**: Chassis camera = main view, turret camera = PIP. Press VIEW to swap.
- **FCS**: Crosshair centered on turret view, movable in middle 1/3 vertically. Barrel angle adjusts with crosshair. FCS computes trajectory based on range, ball speed, hop-up, chassis speed, turret angle.
- **Trajectory Equation**: `angle = gravity_comp + drag_comp - hopup_comp + motion_comp + bias` (5 tunable coefficients)
- **RL Training**: Shot data uploaded to server every 5 shots. Server runs gradient descent on coefficients. Updated coefficients deployed back to tablet.
- **Network Hub**: GL.iNet router broadcasts local SSID for direct tank-to-tablet connection. Anker power bank + Sabrent USB hub for standalone operation.
- **Deploy**: `.\system\deploy_app.ps1` (Windows) or `./system/deploy_app.sh` (bash). Builds APK and installs via ADB.

### Train Console (RPi4 + Joystick)
- **Display**: 7" RPi touch display (800x480), tilted 15°
- **Joystick**: PS2 potentiometer module via MCP3008 ADC — analog throttle lever feel
- **Camera**: Single ESP32-CAM forward-facing from locomotive nose
- **Control**: Speed (-100 to +100), horn (buzzer), headlight/taillight LEDs
- **Auto-AP**: RPi4 creates hotspot (`TRAIN_CONSOLE`) or connects to train AP (`TRAIN_CTRL`)
- **Setup**: `console/rpi_setup.sh` — installs hostapd/dnsmasq, systemd auto-start
- **Controller**: `console/train_controller.py` — pygame display + WebSocket to ESP32

### Unified Flutter App
- **Model detection**: Project selection screen shows both tank and train entries
- **Tank UI**: Dual-camera PIP, dual joysticks, FCS crosshair, fire button (dark/green theme)
- **Train UI**: Single camera, vertical throttle slider, horn/lights buttons, speed gauge (blue/silver theme)
- **Routing**: `ControlScreen` auto-switches based on `ProjectEntry.modelType`

## Dashboard API Endpoints
- `GET /api/v1/dashboard` — aggregate system data (servers, GPU, CPU/RAM, services)
- `GET /api/v1/dashboard/gpu` — GPU metrics via nvidia-smi
- `GET /api/v1/dashboard/jobs` — simulation job list from jobs directory
- `GET /api/v1/dashboard/projects` — project list from database
- `GET /api/v1/dashboard/logs?service=planning&limit=100` — recent log entries

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
- **NEVER expose real domain URLs** in any committed file. Domains are stored in GCP Secret Manager (`nl2bot-domains`) and loaded at runtime. Use generic placeholders like `plan.<your-domain>` in docs.
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
