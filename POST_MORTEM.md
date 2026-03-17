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
