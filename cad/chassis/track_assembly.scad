// Track/Bogey Assembly for M1A1 Tank (1:26 scale)
// Each side: side plate, 7 road wheels, drive sprocket, idler wheel,
// track guide rails, and N20 motor mount
// All dimensions in millimeters

use <../libs/common.scad>
use <../libs/m4_hardware.scad>

$fn = 64;

// --- Part Selector ---
part = "assembly"; // "left", "right", "sprocket", "assembly"

// --- Track Assembly Dimensions ---
SIDE_PLATE_LENGTH = 150;
SIDE_PLATE_WIDTH  = 24;  // real 635mm / 26.4 scale
SIDE_PLATE_HEIGHT = 30;
SIDE_PLATE_WALL   = 1.6;

// Road wheels — M1A1 has 7 per side
ROAD_WHEEL_COUNT    = 7;
ROAD_WHEEL_DIA      = 18;
ROAD_WHEEL_THICK    = 8;
ROAD_WHEEL_SPACING  = 19;  // tighter spacing for 7 wheels in 150mm
ROAD_WHEEL_AXLE_DIA = 3;
// First road wheel center X offset from front of side plate
ROAD_WHEEL_X_START  = 12;
// Vertical center of road wheels (from bottom of side plate)
ROAD_WHEEL_Z        = ROAD_WHEEL_DIA / 2 + 2;

// Drive sprocket (rear)
SPROCKET_DIA        = 22;
SPROCKET_THICK      = 10;
SPROCKET_TEETH      = 8;
SPROCKET_TOOTH_H    = 2.5;  // Tooth height (radial)
SPROCKET_SHAFT_DIA  = 3;    // M3 for N20 motor coupling
SPROCKET_X          = SIDE_PLATE_LENGTH - 10;
SPROCKET_Z          = SIDE_PLATE_HEIGHT / 2;

// Idler wheel (front)
IDLER_DIA           = 18;
IDLER_THICK         = 8;
IDLER_AXLE_DIA      = 3;
IDLER_X             = 10;
IDLER_Z             = SIDE_PLATE_HEIGHT / 2;
IDLER_SLOT_LENGTH   = 6;  // Tension adjustment slot

// Track guide rails
RAIL_WIDTH          = 3;
RAIL_HEIGHT         = 2;

// N20 motor mount
N20_BODY_DIA        = 12;
N20_MOUNT_DEPTH     = 25;
N20_BRACKET_WALL    = 2;
N20_BRACKET_WIDTH   = N20_BODY_DIA + 2 * N20_BRACKET_WALL;  // 16
N20_BRACKET_HEIGHT  = N20_BODY_DIA + 2 * N20_BRACKET_WALL;  // 16
N20_BRACKET_LENGTH  = N20_MOUNT_DEPTH + N20_BRACKET_WALL;    // 27

// M4 bolt holes for hull attachment (3 per side, evenly spaced)
BOLT_COUNT          = 3;
BOLT_SPACING        = (SIDE_PLATE_LENGTH - 20) / (BOLT_COUNT - 1);
BOLT_X_START        = 10;
BOLT_Z              = SIDE_PLATE_HEIGHT - 8;

// Hull spacing for assembly view
HULL_W = 139;   // Match new hull width (1:26 scale)

// --- Aesthetic Greebling ---
// Track link panel lines
PANEL_LINE_SPACING = 15;   // Horizontal groove every 15mm
PANEL_LINE_DEPTH   = 0.2;  // 0.2mm deep
PANEL_LINE_WIDTH   = 0.3;  // 0.3mm wide

// Return roller (top of side plate, centered)
RETURN_ROLLER_DIA   = 8;
RETURN_ROLLER_THICK = 6;

// Mud flap (front of side plate)
MUD_FLAP_THICK  = 1;

// --- Track Belt (Continuous Caterpillar Track) ---
// Wraps around road wheels, sprocket, and idler
TRACK_BELT_THICK = 3;        // Track link thickness (visible in renders)
TRACK_BELT_WIDTH = ROAD_WHEEL_THICK + 2;  // Slightly wider than wheels
MUD_FLAP_HEIGHT = 10;

// Top edge chamfer
TOP_CHAMFER = 0.5;

// Shadow gap between wheels and side plate
WHEEL_SHADOW_GAP = 0.15;

// --- Modules ---

// Single road wheel with center hub and bolt detail
module road_wheel() {
    difference() {
        cylinder(d = ROAD_WHEEL_DIA, h = ROAD_WHEEL_THICK, center = true);
        cylinder(d = ROAD_WHEEL_AXLE_DIA, h = ROAD_WHEEL_THICK + 1, center = true);
    }
    // Center hub (raised boss on outer face)
    translate([0, 0, ROAD_WHEEL_THICK / 2])
        cylinder(d = 5, h = 1, $fn = 32);
    // Four bolt heads around center hub
    for (a = [0 : 90 : 270]) {
        rotate([0, 0, a])
            translate([3, 0, ROAD_WHEEL_THICK / 2])
                cylinder(d = 1.2, h = 0.5, $fn = 12);
    }
}

// Drive sprocket with simplified triangular teeth
module drive_sprocket() {
    difference() {
        union() {
            // Base disc
            cylinder(d = SPROCKET_DIA, h = SPROCKET_THICK, center = true);
            // Teeth
            for (i = [0 : SPROCKET_TEETH - 1]) {
                rotate([0, 0, i * 360 / SPROCKET_TEETH])
                    translate([SPROCKET_DIA / 2, 0, 0])
                        // Triangular tooth profile as a cylinder approximation
                        cylinder(d1 = 4, d2 = 1.5, h = SPROCKET_THICK, center = true, $fn = 3);
            }
        }
        // M3 shaft hole
        cylinder(d = SPROCKET_SHAFT_DIA, h = SPROCKET_THICK + 1, center = true);
        // D-flat for motor coupling (cut a flat on one side of the shaft hole)
        translate([SPROCKET_SHAFT_DIA / 2 + 0.3, 0, 0])
            cube([1, SPROCKET_SHAFT_DIA, SPROCKET_THICK + 1], center = true);
    }
}

// Idler wheel
module idler_wheel() {
    difference() {
        cylinder(d = IDLER_DIA, h = IDLER_THICK, center = true);
        cylinder(d = IDLER_AXLE_DIA, h = IDLER_THICK + 1, center = true);
    }
}

// Track guide rail (runs full length along inner face of side plate)
module track_guide_rail() {
    cube([SIDE_PLATE_LENGTH, RAIL_WIDTH, RAIL_HEIGHT]);
}

// N20 motor mount bracket — extends inward from rear of side plate
module n20_motor_mount() {
    difference() {
        // Bracket body
        translate([0, 0, -N20_BRACKET_HEIGHT / 2])
            cube([N20_BRACKET_LENGTH, N20_BRACKET_WIDTH, N20_BRACKET_HEIGHT]);
        // Motor cradle bore (perpendicular to side plate, along Y axis)
        translate([N20_BRACKET_WALL, N20_BRACKET_WIDTH / 2, 0])
            rotate([0, 0, 0])
                translate([0, 0, 0])
                    rotate([0, 90, 0])
                        cylinder(d = N20_BODY_DIA, h = N20_MOUNT_DEPTH + 0.1);
        // Motor shaft exit hole
        translate([-0.1, N20_BRACKET_WIDTH / 2, 0])
            rotate([0, 90, 0])
                cylinder(d = SPROCKET_SHAFT_DIA + 1, h = N20_BRACKET_WALL + 0.2);
    }
}

// Tension adjustment slot (elongated hole) for idler axle
module tension_slot() {
    hull() {
        cylinder(d = IDLER_AXLE_DIA + 0.4, h = SIDE_PLATE_WALL + 0.2, center = true);
        translate([IDLER_SLOT_LENGTH, 0, 0])
            cylinder(d = IDLER_AXLE_DIA + 0.4, h = SIDE_PLATE_WALL + 0.2, center = true);
    }
}

// Panel line grooves on side plate exterior (cut from outer face at Y=0)
module panel_line_grooves() {
    groove_count = floor(SIDE_PLATE_LENGTH / PANEL_LINE_SPACING);
    for (i = [1 : groove_count - 1]) {
        translate([i * PANEL_LINE_SPACING, -0.01, SIDE_PLATE_WALL])
            cube([PANEL_LINE_WIDTH, PANEL_LINE_DEPTH + 0.01, SIDE_PLATE_HEIGHT - 2 * SIDE_PLATE_WALL]);
    }
}

// Return roller — single small roller at top of side plate, centered
module return_roller() {
    translate([SIDE_PLATE_LENGTH / 2, -RETURN_ROLLER_THICK / 2, SIDE_PLATE_HEIGHT])
        rotate([90, 0, 0])
            difference() {
                cylinder(d = RETURN_ROLLER_DIA, h = RETURN_ROLLER_THICK, center = true);
                cylinder(d = ROAD_WHEEL_AXLE_DIA, h = RETURN_ROLLER_THICK + 1, center = true);
            }
}

// Mud flap — thin plate extending down from front of side plate
module mud_flap() {
    translate([0, 0, -MUD_FLAP_HEIGHT])
        cube([MUD_FLAP_THICK, SIDE_PLATE_WIDTH, MUD_FLAP_HEIGHT]);
}

// Generic edge chamfer — 45-degree triangular prism for subtractive chamfering
module edge_chamfer(length, size=0.5) {
    rotate([0, 0, 45])
        cube([size*1.414, size*1.414, length], center=true);
}

// Top edge chamfer — 45-degree cut along the top outer edge (Y=0 side)
module top_edge_chamfer() {
    translate([-0.01, -0.01, SIDE_PLATE_HEIGHT - TOP_CHAMFER])
        rotate([45, 0, 0])
            cube([SIDE_PLATE_LENGTH + 0.02, TOP_CHAMFER * 1.5, TOP_CHAMFER * 1.5]);
}

// Side plate chamfers — bottom and front/rear edges (outer face at Y=0)
module side_plate_chamfers() {
    ch = 0.5;  // Chamfer size

    // Bottom outer edge (full length, Y=0 side, Z=0)
    translate([SIDE_PLATE_LENGTH/2, 0, 0])
        edge_chamfer(SIDE_PLATE_LENGTH + 0.2, ch);

    // Bottom inner edge (full length, Y=SIDE_PLATE_WIDTH side, Z=0)
    translate([SIDE_PLATE_LENGTH/2, SIDE_PLATE_WIDTH, 0])
        edge_chamfer(SIDE_PLATE_LENGTH + 0.2, ch);

    // Front-top edge (X=0, outer face, Z=SIDE_PLATE_HEIGHT)
    translate([0, SIDE_PLATE_WIDTH/2, SIDE_PLATE_HEIGHT])
        rotate([0, 90, 0])
        edge_chamfer(SIDE_PLATE_WIDTH + 0.2, ch);

    // Front-bottom edge (X=0, outer face, Z=0)
    translate([0, SIDE_PLATE_WIDTH/2, 0])
        rotate([0, 90, 0])
        edge_chamfer(SIDE_PLATE_WIDTH + 0.2, ch);

    // Rear-top edge (X=SIDE_PLATE_LENGTH, Z=SIDE_PLATE_HEIGHT)
    translate([SIDE_PLATE_LENGTH, SIDE_PLATE_WIDTH/2, SIDE_PLATE_HEIGHT])
        rotate([0, 90, 0])
        edge_chamfer(SIDE_PLATE_WIDTH + 0.2, ch);

    // Rear-bottom edge (X=SIDE_PLATE_LENGTH, Z=0)
    translate([SIDE_PLATE_LENGTH, SIDE_PLATE_WIDTH/2, 0])
        rotate([0, 90, 0])
        edge_chamfer(SIDE_PLATE_WIDTH + 0.2, ch);
}

// Left side plate with all features
// NOTE: Side plate is a fully closed (watertight) manifold — interior cavity is
// inset by SIDE_PLATE_WALL on all 6 faces (front, rear, inner, outer, top, bottom).
module side_plate_left() {
    difference() {
        union() {
            // Main side plate (hollow box — closed on all faces for valid manifold)
            difference() {
                cube([SIDE_PLATE_LENGTH, SIDE_PLATE_WIDTH, SIDE_PLATE_HEIGHT]);
                translate([SIDE_PLATE_WALL, SIDE_PLATE_WALL, SIDE_PLATE_WALL])
                    cube([
                        SIDE_PLATE_LENGTH - 2 * SIDE_PLATE_WALL,
                        SIDE_PLATE_WIDTH - 2 * SIDE_PLATE_WALL,
                        SIDE_PLATE_HEIGHT - 2 * SIDE_PLATE_WALL
                    ]);
            }

            // Track guide rails on inner face (Y = SIDE_PLATE_WIDTH side faces hull)
            // Bottom rail
            translate([0, SIDE_PLATE_WIDTH - RAIL_WIDTH, SIDE_PLATE_WALL])
                track_guide_rail();
            // Top rail
            translate([0, SIDE_PLATE_WIDTH - RAIL_WIDTH, SIDE_PLATE_HEIGHT - SIDE_PLATE_WALL - RAIL_HEIGHT])
                track_guide_rail();

            // N20 motor mount bracket extending inward from rear
            translate([SIDE_PLATE_LENGTH - N20_BRACKET_WALL, SIDE_PLATE_WIDTH, SPROCKET_Z])
                rotate([0, 0, 0])
                    translate([0, 0, 0])
                        n20_motor_mount_positioned();

            // Mud flap at front
            mud_flap();
        }

        // Panel line grooves on exterior face
        panel_line_grooves();

        // Top edge chamfer on outer face
        top_edge_chamfer();

        // Chamfers on bottom, front, and rear edges
        side_plate_chamfers();

        // M4 bolt holes for hull attachment (through inner wall, top region)
        for (i = [0 : BOLT_COUNT - 1]) {
            translate([BOLT_X_START + i * BOLT_SPACING, SIDE_PLATE_WIDTH - 0.05, BOLT_Z])
                rotate([-90, 0, 0])
                    rotate([180, 0, 0])
                        m4_hole(depth = SIDE_PLATE_WALL + 0.1);
        }

        // Road wheel axle holes (through outer wall)
        for (i = [0 : ROAD_WHEEL_COUNT - 1]) {
            translate([ROAD_WHEEL_X_START + i * ROAD_WHEEL_SPACING, -0.05, ROAD_WHEEL_Z])
                rotate([-90, 0, 0])
                    cylinder(d = ROAD_WHEEL_AXLE_DIA + 0.4, h = SIDE_PLATE_WALL + 0.1);
        }

        // Sprocket axle hole (through outer wall)
        translate([SPROCKET_X, -0.05, SPROCKET_Z])
            rotate([-90, 0, 0])
                cylinder(d = SPROCKET_SHAFT_DIA + 0.4, h = SIDE_PLATE_WALL + 0.1);

        // Idler tension slot (through outer wall)
        translate([IDLER_X, SIDE_PLATE_WALL / 2, IDLER_Z])
            rotate([0, 0, 0])
                translate([-IDLER_SLOT_LENGTH / 2, 0, 0])
                    rotate([90, 0, 0])
                        rotate([0, 0, 0])
                            tension_slot_through();
    }
}

// Tension slot cut through side plate outer wall
module tension_slot_through() {
    hull() {
        cylinder(d = IDLER_AXLE_DIA + 0.4, h = SIDE_PLATE_WALL + 0.2, center = true);
        translate([IDLER_SLOT_LENGTH, 0, 0])
            cylinder(d = IDLER_AXLE_DIA + 0.4, h = SIDE_PLATE_WALL + 0.2, center = true);
    }
}

// N20 motor mount positioned to extend inward (along +Y) from rear of plate
module n20_motor_mount_positioned() {
    // Bracket extends along +Y (toward hull center)
    // Motor axis along X (perpendicular to side plate face)
    difference() {
        translate([-(N20_BRACKET_LENGTH - N20_BRACKET_WALL), 0, -N20_BRACKET_HEIGHT / 2])
            cube([N20_BRACKET_LENGTH, N20_MOUNT_DEPTH + N20_BRACKET_WALL, N20_BRACKET_HEIGHT]);
        // Motor cradle bore along X axis
        translate([-(N20_MOUNT_DEPTH + 0.05), (N20_MOUNT_DEPTH + N20_BRACKET_WALL) / 2, 0])
            rotate([0, 90, 0])
                rotate([90, 0, 0])
                    rotate([0, 0, 0])
                        translate([0, 0, 0])
                            rotate([90, 0, 0])
                                translate([0, 0, -(N20_MOUNT_DEPTH + N20_BRACKET_WALL) / 2])
                                    cylinder(d = N20_BODY_DIA, h = N20_MOUNT_DEPTH + 0.1);
        // Shaft pass-through to sprocket
        translate([0.05, (N20_MOUNT_DEPTH + N20_BRACKET_WALL) / 2, 0])
            rotate([0, -90, 0])
                cylinder(d = SPROCKET_SHAFT_DIA + 1, h = N20_BRACKET_LENGTH + 0.2);
    }
}

// --- Track Belt (Continuous Caterpillar) ---
// Reliable approach: 4 simple cubes forming a rectangular loop
module track_belt() {
    t = TRACK_BELT_THICK;
    rw_bottom = ROAD_WHEEL_Z - ROAD_WHEEL_DIA / 2;   // Z=2
    belt_z = rw_bottom - t;                             // Z=0 (ground contact)
    top_z = SIDE_PLATE_HEIGHT - 3;                      // Top return path
    front_x = IDLER_X - IDLER_DIA / 2 - 2;             // Front of track
    rear_x = SPROCKET_X + SPROCKET_DIA / 2 + SPROCKET_TOOTH_H + 2;  // Rear
    belt_w = TRACK_BELT_WIDTH;
    belt_y = -(belt_w / 2);

    // Bottom run (ground contact — this IS the lowest point)
    translate([front_x, belt_y, belt_z])
        cube([rear_x - front_x, belt_w, t]);

    // Top run (return path)
    translate([front_x, belt_y, top_z])
        cube([rear_x - front_x, belt_w, t]);

    // Front vertical (wraps around idler)
    translate([front_x - t, belt_y, belt_z])
        cube([t, belt_w, top_z + t - belt_z]);

    // Rear vertical (wraps around sprocket)
    translate([rear_x, belt_y, belt_z])
        cube([t, belt_w, top_z + t - belt_z]);
}

// Complete left track assembly with wheels
module track_assembly_left() {
    // Side plate with all cutouts and brackets
    side_plate_left();

    // Return roller at top of side plate
    return_roller();

    // Road wheels on outer face (with shadow gap from side plate)
    for (i = [0 : ROAD_WHEEL_COUNT - 1]) {
        translate([ROAD_WHEEL_X_START + i * ROAD_WHEEL_SPACING,
                   -(ROAD_WHEEL_THICK / 2 + WHEEL_SHADOW_GAP), ROAD_WHEEL_Z])
            rotate([90, 0, 0])
                road_wheel();
    }

    // Drive sprocket at rear
    translate([SPROCKET_X, -SPROCKET_THICK / 2, SPROCKET_Z])
        rotate([90, 0, 0])
            drive_sprocket();

    // Idler wheel at front
    translate([IDLER_X, -IDLER_THICK / 2, IDLER_Z])
        rotate([90, 0, 0])
            idler_wheel();

    // Continuous track belt wrapping all wheels
    color("#2a2a2a")
    track_belt();
}

// Right side is a mirror of the left
module track_assembly_right() {
    translate([0, HULL_W + 2 * SIDE_PLATE_WIDTH, 0])
        mirror([0, 1, 0])
            track_assembly_left();
}

// --- Part Selection ---

if (part == "left") {
    track_assembly_left();
} else if (part == "right") {
    // Show right side at origin for printing
    mirror([0, 1, 0])
        track_assembly_left();
} else if (part == "sprocket") {
    drive_sprocket();
} else if (part == "assembly") {
    // Both sides at correct spacing
    // Left track: Y = 0 (outer face at Y = -wheel offset)
    track_assembly_left();
    // Right track: mirrored, spaced at hull_width + 2*track_width
    track_assembly_right();
}
