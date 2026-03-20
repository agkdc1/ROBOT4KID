# POST MORTEM LOG

## Entry 001 — Assembly Positioning Failures (2026-03-17)

### [Issue]
3D viewer showed tank parts incorrectly positioned: hull appeared as 300mm flat plate (two halves end-to-end), turret overlapping hull on Z axis, barrel pointing vertically instead of horizontally, tracks only 150mm long vs 300mm hull.

### [Root Cause]
1. `assembly.scad` used `use` instead of `include` for `common.scad`, so variables (`TRACK_WIDTH`, `HULL_WIDTH`) were undefined — tracks failed to render.
2. Gun trunnion was at turret X=105 (rear end) while cheek armor was at X=0 (front end) — rotating turret 180deg to face gun forward put cheek armor backward.
3. Barrel rotation `rotate([0, -5, 0])` only tilted 5deg from vertical instead of rotating 90deg to horizontal.
4. Only one track assembly rendered per side, covering half the hull length.

### [Resolution]
1. Changed `use` to `include` in assembly.scad for variable access.
2. Moved gun_trunnion to turret front (X=15) to match cheek armor side.
3. Changed barrel rotation to `rotate([0, -85, 0])` for near-horizontal aim.
4. Placed two track assemblies per side (front + rear) to cover full hull length.
5. Created `full_assembly.stl` pre-rendered from corrected assembly.scad.

### [Pipeline Update]
- Always verify STL part IDs match robot_spec.json joint references.
- When assembly uses variables from library files, use `include` not `use` in OpenSCAD.
- Always render `assembly.scad` as a validation step before serving individual parts.
- Gun/sensor placement must be on the same end as armor facing (front = gun + cheek armor).

## Entry 002 — Track Belt & Ground Contact (2026-03-17)

### [Issue]
Track belt geometry failed to render (non-manifold from complex cylinder-arc operations).
Gemini repeatedly flagged "floating tracks" because hull was elevated above tracks.
Hull split line groove was flagged as "open hull gap."

### [Root Cause]
1. Complex cylinder difference() operations for track arc wraps produced non-manifold geometry that OpenSCAD silently dropped.
2. Gemini audit lacked physics context — didn't know that tank hulls FLOAT above tracks on suspension.
3. Top/bottom split grooves (0.4mm aesthetic detail) looked like structural gaps in renders.

### [Resolution]
1. Replaced cylinder-arc track belt with simple 4-cube rectangular loop (bottom run + top return + front/rear verticals). Reliable manifold geometry.
2. Added physics-aware context to Gemini audit prompt: "track belt touches ground, hull floats on suspension."
3. Removed top/bottom split grooves, kept side grooves only.
4. Added ground plane reference to assembly.scad for visual verification.

### [Pipeline Update]
- Always use simple primitives (cubes, cylinders) for structural geometry. Avoid complex boolean intersections.
- Gemini audit prompt MUST include model-specific physics context (tank vs train vs other).
- Visual aesthetic grooves on critical surfaces (top deck, bottom) can be misinterpreted as defects — keep them shallow or remove.
- Always include a ground plane in assembly renders for contact verification.

## Entry 003 — Train Wheel Orientation (2026-03-17)

### [Issue]
Train wheels rendered lying flat (horizontal) instead of standing upright (vertical).
Gemini audit scored 10/10 without catching this critical physics violation.

### [Root Cause]
1. locomotive.scad only had wheel_bosses() (axle holes) — no actual visible wheel geometry.
2. train_assembly.scad had no wheel cylinders at all.
3. Gemini audit prompt lacked wheel orientation check for trains.

### [Resolution]
1. Added visible wheel cylinders to train_assembly.scad with rotate([90,0,0]) for vertical orientation.
2. Added "wheels MUST be VERTICAL" as CRITICAL check in train audit context.
3. Added camera aperture check for both tank and train audit contexts.

### [Pipeline Update]
- Always render visible wheel/track geometry in assembly files (not just axle holes).
- Audit prompt must explicitly check physical orientation of wheels (vertical for trains, inside track belt for tanks).
- Sensor aperture holes (camera, ToF) must be verified — without them the robot is BLIND.

## Entry 004 — Motor-Wheel Drivetrain Mismatch (2026-03-17)

### [Issue]
Tank hardware spec changed to TT Motors (65x22x18mm) but CAD track_assembly still has N20 motor mounts (12mm diameter bore). TT motor physically cannot fit in the N20 cradle. Gemini scored the model 10/10 without catching this because the audit only checks visual appearance, not mechanical compatibility.

### [Root Cause]
1. Hardware spec was updated (N20 -> TT Motor) without updating the corresponding CAD mount geometry.
2. The URDF/robot_spec.json doesn't encode motor-to-mount compatibility constraints.
3. Gemini's visual audit cannot see internal motor mount dimensions — it only sees the external shell.
4. The structural_audit() function checks boolean breach and manifold, NOT drivetrain chain compatibility.

### [Resolution]
1. Must decide: keep N20 motors (match existing CAD) OR redesign track_assembly for TT motors.
2. Add drivetrain chain validation to the pipeline:
   - Motor shaft diameter must match coupling bore
   - Coupling output must match sprocket/gear shaft
   - Gear/sprocket must mesh with driven element
   - Driven element must connect to wheel/axle

### [Pipeline Update]
- Add "DRIVETRAIN CHAIN AUDIT" to structural_audit():
  - Parse motor dimensions from hardware_specs.yaml
  - Parse mount dimensions from SCAD source
  - Verify motor_body_diameter <= mount_bore_diameter
  - Verify shaft_diameter matches coupling bore
- The URDF RobotSpec should include drivetrain links as joints with actuator specs.
- Gemini prompt should include: "Verify motor type matches mount geometry. If spec says TT Motor but CAD has N20 mount, flag as CRITICAL."
- NEVER change hardware spec without updating corresponding CAD geometry in the same commit.

## Entry 005 — Webots Streaming Camera Issues (2026-03-17)

### [Issue]
Webots X3D streaming viewer shows ground-level view — robots too small to see.
Camera viewpoint from .wbt file is not properly applied in web streaming mode.
Multiple Webots instances created when taskkill fails to terminate properly.

### [Root Cause]
1. Webots streaming X3D mode sends initial scene state but the web viewer's camera doesn't match the .wbt Viewpoint node.
2. The robots (0.3m tank, 0.13m train) are tiny in a 2m arena — default web camera is too far.
3. WheelEvent dispatching doesn't affect the X3D viewer's camera (server-side rendered).
4. MJPEG mode requires different --stream arguments than X3D mode.
5. Background bash `&` launches aren't properly tracked, causing zombie Webots processes.

### [Resolution]
1. For video capture, use Webots GUI mode with `File > Make Movie` (not streaming).
2. Or use `--stream=mjpeg` flag specifically for MJPEG streaming.
3. Always use `powershell.exe -Command "Get-Process webots | Stop-Process -Force"` to kill ALL instances.
4. For production: use the React dashboard's SimulationViewer which handles the WebSocket connection properly.

### [Pipeline Update]
- Webots streaming is best consumed by the React SimulationViewer component, not the raw streaming_viewer.
- For Gemini video audit, record via Webots GUI movie export OR supervisor controller screenshot API.
- Never launch Webots with `&` in bash without proper PID tracking.
- Consider Webots supervisor's `wb_supervisor_movie_start_recording()` for headless video capture.

## Entry 006 — Cloud Run Custom Domain via Cloudflare (2026-03-20)

### [Issue]
Cloud Run returns 404 when accessed through Cloudflare-proxied custom domains (plan.*, sim.*, app.*). Cloudflare sends the custom hostname in the Host header, but Cloud Run only accepts its own `.run.app` hostname.

### [Root Cause]
1. Cloud Run rejects requests with unknown Host headers at the Google frontend (before reaching the app).
2. Cloudflare Origin Rules (Host header rewrite) requires Pro plan — not available on free tier.
3. Cloud Run domain mappings require DNS-only mode for cert provisioning, which disables Cloudflare Access.

### [Resolution]
Used a **Cloudflare Worker** (free 100k req/day) to rewrite the Host header before forwarding to Cloud Run. Worker also adds a shared secret header (`X-Worker-Secret`) for origin verification. Planning server middleware rejects requests without the secret (except `/api/v1/health`).

### [Pipeline Update]
- When using Cloudflare free tier + Cloud Run, always use a Worker for Host header rewrite.
- Origin Rules and Transform Rules cannot modify the Host header on Cloudflare free tier.
- Add a shared secret between Worker and Cloud Run to prevent direct access bypassing Cloudflare Access.
- Store Worker secret in GCP Secret Manager, inject via Cloud Run env var.

## Entry 007 — Cloudflare Access Blocks SPA Assets (2026-03-20)

### [Issue]
React dashboard SPA served via Cloudflare Access showed blank page. HTML loaded but JS/CSS assets returned 302 (redirect to Access login).

### [Root Cause]
1. Cloudflare Access's `same_site_cookie_attribute` was unset (defaulting to `Lax`).
2. With `Lax`, the `CF_Authorization` cookie wasn't sent on subresource requests (script/stylesheet loads) in some browser contexts.
3. Without the cookie, Access treated asset requests as unauthenticated and redirected to login.

### [Resolution]
Set `same_site_cookie_attribute: "none"` on the Cloudflare Access Application via API. This ensures the Access cookie is sent on all same-origin requests including JS/CSS asset loads.

### [Pipeline Update]
- When serving SPAs behind Cloudflare Access, always set `same_site_cookie_attribute: "none"`.
- Default `Lax` breaks asset loading for single-page applications.
- Test asset loading (not just HTML) when verifying Access-protected SPAs.

## Entry 008 — SPA Routing at Root Path (2026-03-20)

### [Issue]
React dashboard mounted at `/dashboard/` required `basename` in BrowserRouter, and assets needed Vite `base: "/dashboard/"` config. Mounting at `/` conflicted with existing HTMX web UI router.

### [Root Cause]
1. FastAPI `app.mount("/", StaticFiles(...))` captures ALL routes, including `/api/*`, if defined before API route handlers.
2. The HTMX `web_router` had a `/` route that took precedence over the SPA mount.

### [Resolution]
1. Moved HTMX web UI to `/legacy/` prefix.
2. Defined health check and all API routers BEFORE the SPA mount.
3. SPA mount at `/` with `html=True` is the LAST route — catches only unmatched paths.
4. Vite `base: "/"` and BrowserRouter with no basename — simplest config.

### [Pipeline Update]
- In FastAPI, `app.mount("/", ...)` MUST be the last route added — it catches everything.
- Define all API routers and explicit routes before any catch-all SPA mount.
- When migrating from multi-page to SPA, move the old UI to a prefix rather than removing it.
