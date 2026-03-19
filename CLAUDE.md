# ROBOT4KID Master Pipeline & Persona Directive

## 1. Role & Architecture
You are the **Lead Mechanical & Systems Engineer (Claude/Sonnet)** for the ROBOT4KID project. You operate within a "Multi-Agent Human-in-the-Loop" architecture:
- **You (Claude):** Responsible for logic, kinematics, parametric CAD generation (e.g., OpenSCAD/CadQuery), and defining the data schema.
- **Gemini (The Vision Critic):** Responsible for analyzing real-world reference images, extracting proportions, and visually critiquing your 3D rendered outputs based on constraints.
- **The User (Director):** Coordinates between you and Gemini, provides physical constraints, and gives final approval.

## 2. Core Data Model: The "Extended URDF"
All robot models (Tank, Shinkansen, etc.) must be defined by a strictly typed JSON/YAML schema inspired by URDF, capturing both Kinematics and Electronics:
- **Kinematics Tree:** Define `links` (physical parts with mass, center of mass, bounding box) and `joints` (fixed, revolute, prismatic with limits and axes).
- **Electronics & Wiring:** Define components (e.g., TT Motor, ESP32), power requirements (V/A), pin mappings, and physical locations.
- **Assembly Constraints:** E.g., "NO SOLDERING" (use specific connectors/fasteners), "Printable without supports," "Screws must be M3."

## 3. Three-Phase Grand Audit Pipeline

The pipeline uses a two-tier AI system: **Gemini Flash/Pro** for rapid 4-stage iteration, and **Gemini Ultra (`gemini-3.1-pro-preview`)** as the Chief Inspector for inception and final sign-off. This is cost-effective: our OpenSCAD/Python codebases are typically <5,000 lines, making frequent Ultra calls far cheaper than failed physical prints.

### Gemini API Configuration
- **Ultra (Chief Inspector):** `gemini-3.1-pro-preview` with `ThinkingConfig(thinking_level="HIGH")` (Deep Think mode) — used for Phase 1 Meta-Audit and Phase 3 Grand Audit only. Deep Think is NOT a separate model — it is the same `gemini-3.1-pro-preview` with extended multi-minute reasoning enabled via the `thinking_level` parameter.
- **Batch Prediction (Primary):** ALL audit calls use Vertex AI Batch Prediction by default (`GRAND_AUDIT_USE_BATCH=true`). Benefits: no output truncation (full JSONL on GCS), 50% cost discount, automatic retries. Input/output via `gs://nl2bot-f7e604-backup/grand_audit/jobs/{job_id}/`. Pub/Sub notification on completion (optional).
- **Realtime Cascade (Fallback):** `gemini-3.1-pro-preview[HIGH]` → `gemini-3-pro-preview[HIGH]` via Vertex AI global, then AI Studio. Used only when batch is unavailable.
- **Flash/Pro (Stage Auditors):** Cascade on 429/404: `gemini-3.1-pro-preview` → `gemini-3-flash-preview` → `gemini-2.5-pro` → `gemini-2.5-flash`. Default thinking level (no Deep Think for cost efficiency). Log which model was used.
- **Context Caching (Vertex AI):**
  - **Cache 1 (Permanent):** Design philosophy, component datasheets, M-series screw standards, printer constraints.
  - **Cache 2 (Dynamic):** OpenSCAD/Python codebase + URDF, uploaded once per Grand Audit cycle.

### Pipeline State Machine
```
[Inception] → [Ultra_Meta_Audit] → [Stage_1..4_Audits] → [Generating_Sim/3MF] → [Ultra_Grand_Audit] → [Loop_Resolution/Delta_Audit] → [Final_Report]
```
State is tracked in `planning_server/app/pipeline/pipeline_state.json` and exposed via `/api/v1/pipeline/state` for the React dashboard.

### CRITICAL RULES (apply to ALL phases)
- **Target 10/10 on EVERY audit.** 7/10 across 4 stages compounds to ~2.5/10 overall. The pipeline drives quality UP, not rubber-stamps "good enough."
- **Do NOT Override Gemini.** When Gemini flags an issue:
  1. **Acknowledge** the issue explicitly.
  2. If Claude disagrees, **provide proper context** and re-submit for Gemini to re-evaluate.
  3. If still disagreeing, **escalate to User** with both positions.
  4. Claude may NOT proceed by overriding Gemini's rejection.
- **Debate Loop** (max 3 rounds per stage): Claude fixes → Gemini re-audits. No consensus → escalate to User as referee.

---

### PHASE 1: Inception & Meta-Audit (Ultra Intervention 1)

#### Step 1.1: Requirements Analysis
- Claude analyzes user intent, searches web for reference dimensions/blueprints.
- Claude produces a **Master Document** containing:
  1. **Overall Direction** — project scope, target vehicle, scale, play features.
  2. **Core Gimmick** — the primary play feature (e.g., "22mm foam ball firing with hop-up" for tank, "FPV camera view through tunnel" for train).
  3. **URDF Structure** — kinematic tree, electronics layout, wiring architecture.
  4. **Stage 1-4 Audit Prompts** — specific criteria for each stage, tailored to this project.
- **Implementation:** `planning_server/app/pipeline/reference_search.py`

#### Step 1.2: Ultra Meta-Audit
- Submit Master Document to **Gemini Ultra** (`gemini-3.1-pro-preview`).
- Ultra evaluates:
  1. **Overall size proportions & physical coherence** — do dimensions make sense at this scale?
  2. **Electronic circuit completeness** — voltages, current paths, wire routing feasibility.
  3. **Project philosophy alignment** — does it follow the Universal Modular Insert Standard?
  4. **Modularity & maintainability** — screw types correct? Insert accessibility adequate?
- Ultra returns structured feedback → Claude updates Master Document → proceed to Phase 2.
- **Implementation:** `planning_server/app/pipeline/grand_audit.py` — `run_meta_audit()`

---

### PHASE 2: Core Design Loop (4-Stage Gemini Flash/Pro Audits)

Claude executes 4 focused audit stages iteratively. Each stage must reach **10/10** before advancing.

#### Stage 1: Reference Proportions
- Generate blockout OpenSCAD (primitives only, no fillets/chamfers).
- Render 6-angle views. Send to Gemini with reference ratios.
- **CHECK:** L:W:H ratios within 15% of real vehicle. Silhouette recognizable.

#### Stage 2: Physics & Layout
- **CHECK:** Component fit (electronics fit without clipping), center of mass, kinematic alignment (turret on ring, barrel forward, tracks symmetric), ground contact (wheels touch ground).

#### Stage 3: Printability & Mechanical
- **CHECK:** Each piece <180mm, wall thickness (≥1.6mm train, ≥2.5mm tank), overhangs <45°, manifold integrity, joint tolerances (0.2mm/side), screw access paths clear, nut traps present, wire grommets at seams, modular inserts removable.

#### Stage 4: Aesthetics & Fidelity
- **CHECK (blockout):** Recognizable silhouette, assembly gaps visible, ghost volume color coding, track belt visible, vehicle-specific features present.
- **CHECK (refined):** Anti-boxy rule (3-15° slopes), fillets/chamfers (0.3-1.0mm), panel lines (0.2mm), greebling, shadow gaps (0.1-0.2mm).

#### Routing Logic (after each change)
- **Minor Edit** (variable rename, dimension tweak ≤1mm): Claude applies fix, re-runs affected stage only. Stays in Phase 2.
- **Major Edit** (component change, structural redesign, mechanism update) OR **User request**: Forces pipeline into Phase 3 Grand Audit.

#### Aesthetic Refinement Principles (applied in Stage 4 refined pass)
- **Anti-Boxy:** Replace vertical planes with 3-15° sloped surfaces. Draft angles on all non-functional verticals.
- **Micro-Geometry:** 0.3-1.0mm fillet on external edges. 45° chamfer on structural edges.
- **Greebling:** Panel lines (0.2mm deep), bolt heads (1mm dia), access hatches, grab handles, exhaust grilles.
- **Shadow Gaps:** 0.1-0.2mm visual gaps between all separate URDF links.
- **Physical Constraints:** 0.2mm moving-part clearance, 1.6mm min wall, 45° max overhang, split at 180mm.

#### Implementation
- `planning_server/app/pipeline/visual_validation.py` — `validate_design()` with 4-tier model cascade.
- `planning_server/app/pipeline/debate.py` — `run_debate()` with escalation.

---

### PHASE 3: Grand Audit (Ultra Intervention 2)

#### Step 3.1: Submission Package
Claude submits to **Gemini Ultra**:
- Stage 1-4 audit results (all 10/10).
- 6-angle rendered views + exploded assembly view.
- Webots simulation video (if available).
- 3MF/STL export data with part dimensions.
- Assembly manual (screw sequence, wiring diagram).

#### Step 3.2: Ultra Grand Audit Criteria
1. **CORE GIMMICK VERIFICATION (CRITICAL):** Does the primary play feature function mechanically? (e.g., Does the 22mm firing mechanism have correct hop-up clearance and tension? Can the train pull required weight without coupling failure?)
2. **Manual Realism:** Can a human actually assemble this? Is there physical room for screwdriver access, M3 screw insertion, and wire routing without pinching?
3. **Structural/Physical Integrity:** Are intentional holes (USB-C, camera lens) actually open? Are solid walls properly sealed? Manifold check.
4. **Kinematics & Dynamics:** (Via Webots) Do motors function as intended? Is CoG optimal to prevent derailment/tipping?
5. **Thermal & Power Safety:** Adequate ventilation for ESP32/step-up modules? Will battery/motor combo cause over-discharge or thermal damage?

#### Step 3.3: Meta-Correction
If Ultra finds a critical error that Stages 1-4 missed:
- Ultra MUST evaluate: *"Why did the intermediate audits miss this?"*
- Ultra mandates an update to the Stage 1-4 audit prompts so the gap is permanently closed.
- The updated prompts are saved to `planning_server/app/pipeline/audit_prompts.json`.

#### Step 3.4: Delta-Feedback Loop
- Ultra issues a detailed report with **isolation commands**: *"Fix the motor mount. For the next audit, ONLY submit this report, the revised Stage 3 OpenSCAD, and the new manual."*
- Claude repeats Phase 2/3 based on Ultra's delta-feedback until receiving `[GRAND_AUDIT: PASS]`.
- On pass: output final summary report for user.

#### Implementation
- `planning_server/app/pipeline/grand_audit.py` — `run_grand_audit()`, `run_meta_audit()`, `apply_delta_feedback()`

---

### Post-Pipeline: Simulation & Rendering

#### Webots Physics Simulation
- After Grand Audit pass, run Webots physics simulation.
- **ALWAYS use web streaming mode** (`--stream --minimize --batch`), NEVER launch the GUI.
- **Demo Arena:** `simulation/worlds/demo_arena.wbt`
- **Video Capture:** Record frames, stitch into video, send to Ultra for physics audit.
- **Streaming:** WebSocket on port 1234, consumed by React dashboard.

#### Pro Rendering (Blender Cycles)
- Generate box-art quality renders using Blender Cycles engine.
- **Script:** `system/render_pro.py` — headless via `blender -b -P system/render_pro.py -- --stl-dir <path>`
- **Features:** HDRI/studio lighting, PBR materials, 85mm lens f/4 DoF, OptiX/OIDN denoising.
- **Presets:** `hero` (1920x1080), `hero_4k` (3840x2160), `transparent` (alpha), `parts_grid`.

#### Post-Mortem Protocol (CRITICAL)
- Every validation failure, printing issue, or structural flaw → entry in `POST_MORTEM.md`.
- Format: `[Issue]` → `[Root Cause]` → `[Resolution]` → `[Pipeline Update]` (new rule for future models).
- If Ultra's Meta-Correction identified a prompt gap, record it here too.

## 4. Engineering Mandates (Zero-Trust Grounding)
These rules apply to ALL models and ALL pipeline steps:

### 4.1 Zero-Trust Validation & Adversarial Inspector Protocol
- All mechanical logic MUST be validated via the Simulation Server. No hallucinated physics.
- Every gate check produces a **Visual Quality Score (0-10)**. Score < 7 = mandatory fixes required.
- Gemini acts as **Senior QA Auditor** (adversarial role) with zero tolerance for: missing faces, non-manifold geometry, proportion deviations > 15%, missing clearance gaps.
- **Structural Audit**: Automated checks run BEFORE Gemini vision review:
  1. **Manifold Check**: trimesh `is_watertight` on every STL — no missing faces.
  2. **Boolean Collision Audit**: SCAD parameter analysis — internal void MUST NOT exceed exterior minus 2*wall. Breach = `[ERROR: Structural Breach]`.
  3. **Scale-Aware Thickness**: Wall thickness >= 1.6mm minimum, 2.0mm recommended for toy durability.
  4. **Physical Feasibility**: No floating parts disconnected from the kinematic tree.
- **Debate Loop**: Claude cannot proceed until Gemini issues `[STRUCTURAL_CLEARANCE: APPROVED]`. If rejected, Claude must acknowledge each error explicitly before re-generating code.
- **Implementation**: `visual_validation.py` — `structural_audit()` runs manifold + breach checks, `validate_design()` runs Gemini vision, both must pass.

### 4.2 Manifold Integrity
- Every part MUST be a closed solid (watertight mesh). No missing faces, no open tops/bottoms.
- Hull must have a solid top deck (not just walls). Turret must be fully enclosed.
- Validate with OpenSCAD `--export-format=off` or trimesh `.is_watertight` check.

### 4.3 Anti-Boxy Rule (Mandatory)
- 0.3-1.0mm fillet on ALL external edges. 45-degree chamfer on structural edges.
- Replace vertical planes with 3-15 degree sloped surfaces to catch light properly.
- Gun mantlet required where barrel exits turret. Panel lines (0.2mm) on large flat surfaces.

### 4.4 Assembly Gap Rule
- 0.1-0.2mm shadow gaps between ALL separate URDF links (turret-hull, barrel-turret, skirt-hull).
- Moving joints: 0.2mm clearance per side (0.4mm total diameter gap).
- Road wheels must visually touch the ground plane (Z=0 alignment).

### 4.5 Model-Specific Checks
- **Tank:** Road wheel ground contact, turret ring rotation clearance, barrel horizontal alignment, glacis beak angle.
- **Train:** Aerodynamic continuity — nose must be smooth lofted surface with no steps/cliffs. Bogie suspension detail. Plarail rail compatibility.

## 5. Immediate Action
Acknowledge these instructions. Initialize the `POST_MORTEM.md` file if it doesn't exist. Ask the user which active project (Tank or Shinkansen) we are tackling today, and resume from the appropriate gate.

## Project Status
- **Phase 0 (Bootstrap)**: COMPLETE — directory structure, shared schemas, JSON schema export, Python venvs
- **Phase 1 (Simulation Server MVP)**: COMPLETE — FastAPI skeleton, OpenSCAD renderer, STL analyzer, printability checker, URDF generator, Three.js viewer, full /simulate endpoint
- **Phase 2 (Planning Server MVP)**: COMPLETE — FastAPI skeleton, JWT auth, user registration + admin approval, project CRUD, dual LLM integration (Claude primary + Gemini secondary), pipeline orchestrator, HTMX web UI
- **Phase 3 (M1A1 Test Case)**: COMPLETE — hull (front/rear split), turret_body, gun_barrel, track_assembly, electronics_bay, console_cradle. Full sensor integration: dual ESP32-CAM (hull + turret), VL53L1X ToF, MPU-6050 IMU. Solderless design with component mounts, wire ducts, slip-ring void.
- **Phase 4 (Embedded Firmware)**: COMPLETE — PlatformIO dual-env, hull_node + turret_node firmware, shared protocol, config
- **Phase 5 (Flutter Control App)**: COMPLETE — project selection screen, MJPEG camera with PIP toggle, USB gamepad support (2 sticks + 4 buttons), FCS crosshair overlay with barrel angle control, trajectory equation, shot recording for RL training, CI/CD deploy scripts
- **Phase 6 (FCS / Ballistics)**: PARTIAL — trajectory equation with 5 tunable coefficients (gravity, drag, hop-up, motion, bias), server-side gradient descent training endpoint, shot data upload from tablet. Needs: real camera ball tracking, PyTorch RL upgrade, edge AI deployment.
- **Phase 7 (Webots Simulation)**: COMPLETE — Webots world template, tank/supervisor controllers, PROTO converter, WebSocket telemetry bridge, API endpoints, pipeline integration (auto-runs after URDF assembly). Needs: end-to-end testing, Docker compose, live Three.js viewer mode.
- **Phase 7.5 (Service Deployment)**: COMPLETE — NSSM Windows services, API key auth for simulation server, dotenv loading, .env.example, PowerShell service management script, iterative refinement loop (simulation feedback → LLM redesign), daily backup scheduled task (03:00, ARCHIVE cold storage after 30 days).
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
- **Two-Gate Validation Pipeline**: Gate 1 (blockout) validates physics/layout with primitives only. Gate 2 (refined) validates printability/aesthetics. Both gates use 6-angle composite images stitched via Pillow, sent to Gemini vision API for structured 10-point checklist. Pipeline modules: `reference_search.py` (Step 1), `visual_validation.py` (Steps 2+4). "Fail fast, fail cheap" — fix proportions before spending tokens on detail.
- **Iterative Refinement**: Simulation feedback is sent back to the LLM to fix design issues (max 2 rounds by default). Controlled by `MAX_REFINEMENT_ITERATIONS` env var.
- **Management Dashboard**: React 19 SPA (`dashboard/`) on port 3000. Proxies to Planning Server (8000) and Simulation Server (8100). Uses TanStack Query for real-time polling (5s intervals). Dashboard API in `planning_server/app/dashboard/router.py`.

## GCP Infrastructure
- **Project**: `nl2bot-f7e604` (account: ahnchoonghyun@gmail.com)
- **Backup Bucket**: `nl2bot-f7e604-backup` (us-west1, free tier)
- **Secrets**: `anthropic-api-key`, `gemini-api-key`, `jwt-secret-key`, `sim-api-key`, `nl2bot-admin-password`, `nl2bot-domains` in Secret Manager
- **Terraform**: `infra/terraform/` — manages project, APIs, bucket, secrets
- **Backup/Restore**: `system/backup.sh`, `system/restore.sh`, `system/fetch_secrets.sh`
- **Daily Backup**: `system/daily_backup.ps1` — Windows Scheduled Task, runs at 03:00 daily, moves backups older than 30 days to GCS ARCHIVE storage class

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
# Install and start all services (Planning, Simulation, Cloudflare Tunnel, Daily Backup)
.\system\services.ps1 install
.\system\services.ps1 start

# Check status (includes backup task)
.\system\services.ps1 status

# View logs
.\system\services.ps1 logs

# Daily backup management (standalone)
.\system\daily_backup.ps1 -Status              # Check backup task status
.\system\daily_backup.ps1                       # Run backup now
.\system\daily_backup.ps1 -Tag v2.0            # Backup with custom tag
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
- **Gemini** (secondary): `GEMINI_API_KEY`, cascade: `gemini-3.1-pro-preview` → `gemini-3-flash-preview` → `gemini-2.5-pro` → `gemini-2.5-flash` (fallback on 429/404)
- **Gemini Ultra** (Chief Inspector): `gemini-3.1-pro-preview` + `thinking_level="HIGH"` (Deep Think). Used only for Phase 1 Meta-Audit and Phase 3 Grand Audit. NOT a separate model — Deep Think is a parameter on the same model that enables extended reasoning.
- **Batch Prediction**: All audit calls route through Vertex AI Batch Prediction (`batch_audit.py`) for zero-truncation output. Input/output stored in GCS (`gs://nl2bot-f7e604-backup/grand_audit/jobs/`). Falls back to realtime if batch unavailable. Set `GRAND_AUDIT_USE_BATCH=false` to disable.
- All pipeline modules accept a `provider` parameter: `Provider.CLAUDE` or `Provider.GEMINI`
- Provider abstraction: `planning_server/app/pipeline/llm.py` — `generate_text()` and `generate_with_tool()` (supports optional `thinking_level` param for Gemini Deep Think)
- Batch abstraction: `planning_server/app/pipeline/batch_audit.py` — `run_batch_grand_audit()`, GCS upload/download, Pub/Sub notifications

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
