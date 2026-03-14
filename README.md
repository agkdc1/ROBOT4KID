# NL2Bot

> **Natural Language to Robotics Pipeline** -- describe a robot in plain English, get printable STL files, URDF assembly, physics simulation, and embedded firmware.

NL2Bot takes a natural language description of a robot and runs it through a multi-stage pipeline: LLM-powered NLP, parametric CAD generation (OpenSCAD), printability analysis, URDF assembly, Webots physics simulation, embedded firmware generation, and a Flutter control app. The entire workflow is driven by two cooperating FastAPI servers and dual LLM backends (Claude + Gemini).

The system supports **multiple robot models** through a modular architecture — currently an M1A1 tank (differential drive, dual camera, FCS) and a Shinkansen N700 train (Plarail-compatible, single camera). Any console can control any model via a unified command protocol.

---

## Features

- **Natural language input** -- describe your robot in plain English; the LLM extracts a structured `RobotSpec`
- **Parametric CAD generation** -- OpenSCAD parts auto-generated from spec, with print-constraint validation
- **Printability analysis** -- wall thickness, overhang, build-volume checks against your printer profile
- **URDF assembly** -- joints, links, and collision meshes assembled automatically from STL parts
- **Webots physics simulation** -- URDF-to-PROTO conversion, headless Webots runner, 30 Hz WebSocket telemetry
- **Three.js 3D viewer** -- browser-based STL preview with orbit controls
- **Dual LLM backends** -- Claude Sonnet/Opus (primary) and Gemini Flash (secondary) with provider abstraction
- **JWT authentication** -- user registration, admin approval workflow, role-based access
- **Fire Control System** -- trajectory equation with 5 tunable coefficients, gradient-descent training from shot data
- **Flutter control app** -- MJPEG camera, USB gamepad, FCS crosshair overlay, shot recording for RL training
- **Multi-model support** -- Tank (differential drive, dual camera, FCS) + Train (simple speed, single camera, Plarail-compatible)
- **Multiple consoles** -- Tablet + USB gamepad (tank), RPi4 + 7" display + analog joystick (train)
- **ESP32 firmware** -- PlatformIO triple-target (hull_node, turret_node, train_node), binary command protocol, solderless wiring
- **YAML-driven config** -- All hardware dimensions, speeds, and tunable parameters in a single `config/hardware_specs.yaml`
- **GCP infrastructure** -- Terraform-managed secrets, backups, and project configuration

---

## Architecture

```
                         +--------------------------+
                         |      Web UI (HTMX)       |
                         |   Flutter Control App     |
                         +------------+-------------+
                                      |
                    +-----------------+-----------------+
                    |                                   |
         +----------v-----------+          +------------v-----------+
         |   Planning Server    |          |   Simulation Server    |
         |     (port 8000)      |   HTTP   |      (port 8100)      |
         |                      +--------->|                        |
         |  - JWT Auth          |          |  - OpenSCAD Renderer   |
         |  - Project CRUD      |          |  - STL Analyzer        |
         |  - LLM Pipeline      |          |  - URDF Assembler      |
         |  - FCS Training      |          |  - Printability Check  |
         |  - HTMX Web UI       |          |  - Three.js Viewer     |
         +-----+-------+-------+          |  - Webots Manager      |
               |       |                  +------------+------------+
               v       v                               |
        +------+--+ +--+-------+              +--------v--------+
        | Claude  | | Gemini   |              |     Webots      |
        | Sonnet/ | | Flash    |              | Physics Engine  |
        | Opus    | |          |              | (TCP/WebSocket) |
        +---------+ +----------+              +-----------------+
```

**Pipeline flow:**

```
NL Prompt --> NLP --> RobotSpec --> SCAD Generation --> STL Rendering
    --> Printability Check --> URDF Assembly --> Webots PROTO --> Physics Simulation
```

---

## Quick Start

### Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Python | 3.11+ | Two separate venvs (planning + simulation) |
| OpenSCAD | Latest | Required for STL rendering |
| Webots | R2023b+ | Optional, for physics simulation |
| GCP CLI | Latest | Optional, for secret management |

### Setup

```bash
# Clone
git clone https://github.com/your-org/ROBOT4KID.git
cd ROBOT4KID

# Create virtual environments
python -m venv planning_server/.venv
python -m venv simulation_server/.venv

# Install dependencies (Windows)
planning_server/.venv/Scripts/pip install -r planning_server/requirements.txt
simulation_server/.venv/Scripts/pip install -r simulation_server/requirements.txt

# Install dependencies (Linux/macOS)
planning_server/.venv/bin/pip install -r planning_server/requirements.txt
simulation_server/.venv/bin/pip install -r simulation_server/requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your API keys (ANTHROPIC_API_KEY, GEMINI_API_KEY, etc.)

# Or fetch secrets from GCP Secret Manager
./system/fetch_secrets.sh
```

### Run

```bash
# Terminal 1 — Planning Server
cd planning_server
.venv/Scripts/python -m uvicorn app.main:app --port 8000 --reload   # Windows
.venv/bin/python -m uvicorn app.main:app --port 8000 --reload       # Linux

# Terminal 2 — Simulation Server
cd simulation_server
.venv/Scripts/python -m uvicorn app.main:app --port 8100 --reload   # Windows
.venv/bin/python -m uvicorn app.main:app --port 8100 --reload       # Linux
```

### Verify

```bash
curl http://localhost:8000/api/v1/health   # Planning server
curl http://localhost:8100/api/v1/health   # Simulation server
```

---

## Pipeline

The NL2Bot pipeline transforms a natural language prompt into a physically simulated robot in five stages:

| Stage | Description | Server |
|---|---|---|
| **1. NLP** | LLM extracts a structured `RobotSpec` (parts, joints, dimensions, electronics) from the user's description | Planning |
| **2. CAD Generation** | OpenSCAD source files generated for each part, respecting printer constraints (Bambu A1 Mini: 180x180x180mm) | Planning + Simulation |
| **3. Simulation** | STL rendering, printability analysis (wall thickness, overhangs), mesh metrics (volume, bounding box, manifold check) | Simulation |
| **4. Webots** | URDF assembled from STLs, converted to Webots PROTO, physics simulation with telemetry streaming | Simulation |
| **5. Refinement** | Feedback loop: simulation results fed back to LLM for iterative improvement of the spec | Planning |

---

## Robot Models

### M1A1 Tank (Differential Drive)

| Component | File | Description |
|---|---|---|
| Hull (front/rear) | `cad/chassis/hull.scad` | Split hull, glacis plate, turret ring, camera mount |
| Track Assembly | `cad/chassis/track_assembly.scad` | Side plates, road wheels, sprocket, idler, N20 motor mount |
| Electronics Bay | `cad/chassis/electronics_bay.scad` | Removable tray: ESP32, L298N, LM2596, battery, IMU |
| Turret Body | `cad/turret/turret_body.scad` | Shell, ring, trunnion, ESP32-CAM mount, VL53L1X mount |
| Gun Barrel | `cad/turret/gun_barrel.scad` | Barrel tube, bayonet mount, muzzle brake |
| Console Cradle | `cad/cockpit/console_cradle.scad` | Tablet cradle + GL.iNet router + power bank + USB hub |

### Shinkansen N700 Train (Plarail Compatible)

| Component | File | Description |
|---|---|---|
| Locomotive Body | `cad/train/locomotive.scad` | N700 nose cone, top/bottom snap-fit shells |
| Motor Mount | `cad/train/motor_mount.scad` | N20 motor cradle with axle bearing blocks |
| Battery Bay | `cad/train/battery_bay.scad` | Single 18650 friction-fit cradle |
| Camera Mount | `cad/train/camera_mount.scad` | ESP32-CAM at nose, 10° downward tilt |
| RPi4 Console | `cad/cockpit/train_console.scad` | 7" display + RPi4 + PS2 joystick station |

---

## API Endpoints

### Planning Server (port 8000)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Register new user |
| `POST` | `/api/v1/auth/login` | Login (returns JWT) |
| `POST` | `/api/v1/admin/users/{id}/approve` | Admin: approve user |
| `GET` | `/api/v1/projects` | List projects |
| `POST` | `/api/v1/projects` | Create project |
| `POST` | `/api/v1/pipeline/run` | Run full NL-to-sim pipeline |
| `GET` | `/api/v1/fcs/coefficients` | Get FCS trajectory coefficients |
| `POST` | `/api/v1/fcs/shots` | Upload shot records |
| `POST` | `/api/v1/fcs/train` | Trigger gradient-descent training |
| `GET` | `/api/v1/health` | Health check |

### Simulation Server (port 8100)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/simulate` | Full simulation job |
| `POST` | `/api/v1/render` | Render SCAD to STL |
| `POST` | `/api/v1/analyze` | Analyze STL mesh |
| `POST` | `/api/v1/assemble` | Generate URDF from parts |
| `GET` | `/api/v1/viewer/{job_id}` | Three.js 3D viewer |
| `POST` | `/api/v1/webots/start` | Start Webots simulation |
| `POST` | `/api/v1/webots/stop` | Stop Webots simulation |
| `GET` | `/api/v1/webots/status` | Simulation status |
| `POST` | `/api/v1/webots/command` | Send tank command |
| `WS` | `/api/v1/webots/{job_id}/ws` | Live telemetry stream |
| `GET` | `/api/v1/health` | Health check |
| `GET` | `/api/v1/capabilities` | Server capabilities |

---

## Authentication

**Planning Server** uses JWT-based authentication with admin approval:

1. `POST /api/v1/auth/register` with `{ "username": "...", "password": "..." }`
2. Admin logs in and approves the user via `POST /api/v1/admin/users/{id}/approve`
3. Approved user logs in and receives a JWT token
4. Include token as `Authorization: Bearer <token>` on subsequent requests

Default admin: `admin` / `admin` (configurable via `ADMIN_USERNAME` / `ADMIN_PASSWORD` env vars).

**Simulation Server** uses API key authentication: include `X-API-Key` header with every request.

---

## Configuration

All configuration is via environment variables (`.env` file):

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Claude API key |
| `GEMINI_API_KEY` | Yes | Gemini API key |
| `JWT_SECRET_KEY` | Yes | Secret for JWT signing |
| `SIM_API_KEY` | Yes | API key for simulation server auth |
| `ADMIN_USERNAME` | No | Default admin username (default: `admin`) |
| `ADMIN_PASSWORD` | No | Default admin password (default: `admin`) |
| `WEBOTS_HOME` | No | Path to Webots installation (required for physics sim) |
| `OPENSCAD_PATH` | No | Path to OpenSCAD binary (auto-detected if on PATH) |

Secrets can be fetched from GCP Secret Manager:

```bash
./system/fetch_secrets.sh
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.11+, FastAPI, Pydantic v2, SQLAlchemy (async SQLite) |
| LLM | Claude API (Sonnet / Opus) + Gemini API (Flash) |
| CAD | OpenSCAD, trimesh |
| Simulation | Webots R2023b+, URDF, PROTO |
| Web UI | HTMX, Jinja2, Alpine.js |
| 3D Viewer | Three.js |
| Control App | Flutter / Dart, Material 3, USB gamepad, model-type routing |
| Train Console | Python, pygame, RPi4, MCP3008 ADC, PS2 joystick |
| Firmware | C++ (Arduino), PlatformIO, ESP32 DevKitC V4 + ESP32-CAM |
| Config | YAML (`config/hardware_specs.yaml`) — single source of truth |
| Infrastructure | GCP, Terraform, Secret Manager, Cloud Storage |
| Auth | JWT (planning), API key (simulation) |

---

## Project Structure

```
ROBOT4KID/
├── planning_server/         # Planning + LLM server (port 8000)
│   ├── app/
│   │   ├── auth/            # JWT auth, admin approval
│   │   ├── pipeline/        # LLM pipeline: nlp, cad_gen, llm.py
│   │   ├── projects/        # Project CRUD
│   │   ├── fcs/             # Fire control system / ballistics
│   │   └── web_ui/          # HTMX + Jinja2 templates
│   └── data/                # Generated project files
├── simulation_server/       # Simulation server (port 8100)
│   ├── app/
│   │   ├── renderer/        # OpenSCAD → STL
│   │   ├── analyzer/        # Mesh analysis + printability
│   │   ├── assembler/       # URDF generation
│   │   ├── viewer/          # Three.js STL viewer
│   │   └── simulator/       # Webots manager, bridge, PROTO converter
│   └── jobs/                # Simulation job outputs
├── shared/                  # Shared Pydantic schemas
│   ├── schemas/             # RobotSpec, SimulationRequest, etc.
│   └── json_schemas/        # Exported JSON Schema files
├── cad/                     # OpenSCAD source files
│   ├── chassis/             # Hull, tracks, electronics bay
│   ├── turret/              # Turret body, gun barrel
│   ├── cockpit/             # Console cradle
│   └── libs/                # Shared SCAD libraries
├── simulation/              # Webots worlds and controllers
│   ├── worlds/              # .wbt world files
│   └── controllers/         # Tank + supervisor controllers
├── embedded/                # ESP32 firmware (PlatformIO)
│   ├── src/                 # hull_node, turret_node, train_node
│   └── lib/shared/          # Shared protocol + config (Tank + Train)
├── frontend/                # Flutter control app (unified: tank + train UI)
├── console/                 # RPi4 train console (Python + pygame)
├── config/                  # Hardware specs (YAML, single source of truth)
├── infra/                   # Infrastructure
│   └── terraform/           # GCP Terraform configs
├── system/                  # System scripts
│   ├── backup.sh            # Backup to GCS
│   ├── restore.sh           # Restore from GCS
│   └── fetch_secrets.sh     # Fetch secrets from GCP
├── tests/                   # Tests and reference specs
├── .env.example             # Environment template
└── CLAUDE.md                # Project conventions
```

---

## Testing

```bash
# Health checks
curl http://localhost:8000/api/v1/health
curl http://localhost:8100/api/v1/health

# Run LLM pipeline evaluation
python -m tests.test_llm_pipeline --provider claude --step all
python -m tests.test_llm_pipeline --provider gemini --step nlp

# Start Webots simulation
curl -X POST http://localhost:8100/api/v1/webots/start \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{"job_id":"test"}'

# Backup and restore
./system/backup.sh v1.0
./system/restore.sh v1.0
./system/restore.sh --list
```

---

## License

TBD
