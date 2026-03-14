// Universal Electronic Mount Library
// Parametric cradle generators for cross-model component mounting
// All dimensions in millimeters

// --- Print Tolerances ---
MOUNT_TOLERANCE = 0.2;
MOUNT_CLEARANCE = 0.4;

// =====================================================================
// 1. Universal Friction-Fit Cradle
//    Drop-in box cradle with retaining lips on corners
// =====================================================================
module universal_cradle(length, width, height, wall=2.0, tolerance=MOUNT_TOLERANCE, lip=2.0) {
    inner_l = length + 2 * tolerance;
    inner_w = width + 2 * tolerance;
    outer_l = inner_l + 2 * wall;
    outer_w = inner_w + 2 * wall;
    cradle_h = height * 0.6;

    difference() {
        union() {
            // Outer cradle walls
            cube([outer_l, outer_w, cradle_h]);
            // Retaining lips at top corners
            for (x = [0, outer_l - wall])
                for (y = [0, outer_w - wall])
                    translate([x, y, cradle_h])
                        cube([wall, wall, lip]);
        }
        // Inner cavity
        translate([wall, wall, wall])
            cube([inner_l, inner_w, cradle_h + lip + 0.1]);
    }
}

// =====================================================================
// 2. Standoff Mount Pattern
//    Parametric M2.5/M3 standoff pattern for PCB mounting
// =====================================================================
module standoff_mount(length, width, hole_spacing_x, hole_spacing_y, hole_dia=3.4, standoff_h=5.0, standoff_od=6.0) {
    offset_x = (length - hole_spacing_x) / 2;
    offset_y = (width - hole_spacing_y) / 2;

    positions = [
        [offset_x, offset_y],
        [offset_x + hole_spacing_x, offset_y],
        [offset_x + hole_spacing_x, offset_y + hole_spacing_y],
        [offset_x, offset_y + hole_spacing_y]
    ];

    for (p = positions) {
        translate([p[0], p[1], 0])
            difference() {
                cylinder(h=standoff_h, d=standoff_od);
                translate([0, 0, -0.05])
                    cylinder(h=standoff_h + 0.1, d=hole_dia);
            }
    }
}

// =====================================================================
// 3. Rail Mount (Side-Rail Cradle)
//    Component slides in from one end, held by side rails
// =====================================================================
module rail_mount(length, width, height, rail_w=3, wall=1.5, tolerance=MOUNT_TOLERANCE) {
    inner_l = length + 2 * tolerance;
    inner_w = width + 2 * tolerance;

    difference() {
        union() {
            // Left rail
            cube([inner_l, rail_w, height]);
            // Right rail
            translate([0, rail_w + inner_w, 0])
                cube([inner_l, rail_w, height]);
            // Base plate
            cube([inner_l, inner_w + 2 * rail_w, wall]);
            // Back stop
            cube([wall, inner_w + 2 * rail_w, height]);
        }
        // Component pocket (open at front)
        translate([wall, rail_w, wall])
            cube([inner_l, inner_w, height]);
    }
}

// =====================================================================
// 4. Snap-In Clip
//    Spring-loaded clip cradle (like WAGO style)
// =====================================================================
module snap_clip(length, width, height, wall=1.5, lip=1.0, tolerance=MOUNT_TOLERANCE) {
    inner_l = length + 2 * tolerance;
    inner_w = width + 2 * tolerance;
    clip_h = height * 0.5;

    difference() {
        union() {
            // Outer walls
            cube([inner_l + 2 * wall, inner_w + 2 * wall, clip_h]);
            // Retaining lips on long sides
            for (y = [0, inner_w + wall])
                translate([0, y, clip_h])
                    cube([inner_l + 2 * wall, wall, lip]);
        }
        // Inner cavity
        translate([wall, wall, wall])
            cube([inner_l, inner_w, clip_h + lip + 0.1]);
    }
}

// =====================================================================
// 5. Display Frame
//    Frame mount for flat panel displays (RPi 7", tablet, etc.)
// =====================================================================
module display_frame(screen_w, screen_h, screen_d, bezel=5, wall=2.0, tolerance=MOUNT_TOLERANCE) {
    inner_w = screen_w + 2 * tolerance;
    inner_h = screen_h + 2 * tolerance;
    outer_w = inner_w + 2 * bezel;
    outer_h = inner_h + 2 * bezel;

    difference() {
        // Outer frame
        cube([outer_w, outer_h, screen_d + wall]);
        // Screen recess
        translate([bezel, bezel, wall])
            cube([inner_w, inner_h, screen_d + 0.1]);
        // Viewing window (slightly smaller than screen)
        translate([bezel + 2, bezel + 2, -0.1])
            cube([inner_w - 4, inner_h - 4, wall + 0.2]);
    }
}

// =====================================================================
// 6. Angled Panel Mount
//    Tilted panel for joystick/control surface mounting
// =====================================================================
module angled_panel(width, depth, thickness=3, angle=20, base_h=15) {
    // Tilted panel rising from a base
    hull() {
        // Bottom front edge
        cube([width, thickness, 0.1]);
        // Top back edge (raised and tilted)
        translate([0, depth * cos(angle), base_h + depth * sin(angle)])
            cube([width, thickness, 0.1]);
    }
}

$fn = 64;

// --- Demo ---
// Uncomment to preview:
// universal_cradle(80, 40, 20);
// translate([100, 0, 0]) standoff_mount(85, 56, 58, 49, hole_dia=2.9, standoff_od=5);
// translate([0, 60, 0]) rail_mount(50, 20, 15);
// translate([70, 60, 0]) snap_clip(20, 13, 16);
// translate([0, 100, 0]) display_frame(194, 110, 20);
// translate([0, 230, 0]) angled_panel(80, 50);
