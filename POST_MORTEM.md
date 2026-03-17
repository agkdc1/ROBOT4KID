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
