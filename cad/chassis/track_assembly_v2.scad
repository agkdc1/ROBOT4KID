// Track/Bogey Assembly for M1A1 Tank (1:18 scale)
// Each side: side plate/skirt, 7 road wheels, drive sprocket, idler wheel,
// continuous track belt, N20 motor mount
// All dimensions in millimeters
//
// Real M1A1 track: ~4785mm long, 635mm wide, 760mm tall
// 1/18 scale:       266mm        35mm         42mm
// Side plate length matches hull length (440mm) minus front/rear overhang

$fn = 64;

// --- Part Selector ---
// "left", "right", "sprocket", "assembly"
// "plate_front", "plate_mid", "plate_rear" — split side plate for 180mm bed
part = "assembly";

// =====================================================================
// PARAMETERS (1:18 scale)
// =====================================================================

// --- Side plate / skirt ---
SIDE_PLATE_LENGTH = 400;    // Slightly shorter than hull (440mm) for overhang
SIDE_PLATE_WIDTH  = 35;     // Real 635mm / 18
SIDE_PLATE_HEIGHT = 42;     // Real 760mm / 18
SIDE_PLATE_WALL   = 2.5;

// --- Side plate split for 180mm bed ---
// 3 segments: front (134mm) | mid (133mm) | rear (133mm)
PLATE_FRONT_LEN   = 134;
PLATE_MID_LEN     = 133;
PLATE_REAR_LEN    = 133;
// M4 bolt tabs at split seams
PLATE_BOLT_TAB_W  = 16;
PLATE_BOLT_TAB_H  = 12;
PLATE_BOLT_TAB_D  = 12;
PLATE_BOLT_DIA    = 4.4;

// --- Road wheels (M1A1 has 7 per side) ---
ROAD_WHEEL_COUNT    = 7;
ROAD_WHEEL_DIA      = 26;    // Real ~470mm / 18
ROAD_WHEEL_THICK    = 10;
ROAD_WHEEL_SPACING  = 50;    // ~350mm real / 18, spread across 300mm
ROAD_WHEEL_AXLE_DIA = 3;
ROAD_WHEEL_X_START  = 25;    // Offset from front
ROAD_WHEEL_Z        = ROAD_WHEEL_DIA / 2 + 3;  // Slightly above bottom

// --- Drive sprocket (rear, powered by N20) ---
SPROCKET_DIA        = 30;    // Real ~540mm / 18
SPROCKET_THICK      = 12;
SPROCKET_TEETH      = 11;    // Real M1A1 has 11 teeth
SPROCKET_TOOTH_H    = 3;
SPROCKET_SHAFT_DIA  = 3;     // M3 for N20 coupling
SPROCKET_X          = SIDE_PLATE_LENGTH - 18;
SPROCKET_Z          = SIDE_PLATE_HEIGHT / 2 + 2;

// --- Idler wheel (front, with tensioner slot) ---
IDLER_DIA           = 26;    // Same as road wheels
IDLER_THICK         = 10;
IDLER_AXLE_DIA      = 3;
IDLER_X             = 18;
IDLER_Z             = SIDE_PLATE_HEIGHT / 2;
IDLER_SLOT_LENGTH   = 10;    // +/-5mm tension adjustment

// --- Track belt ---
TRACK_BELT_THICK    = 4;
TRACK_BELT_WIDTH    = ROAD_WHEEL_THICK + 3;

// --- Track guide rails ---
RAIL_WIDTH          = 3;
RAIL_HEIGHT         = 2;

// --- N20 motor mount ---
N20_BODY_DIA        = 12;
N20_MOUNT_DEPTH     = 25;
N20_BRACKET_WALL    = 2;
N20_BRACKET_WIDTH   = N20_BODY_DIA + 2 * N20_BRACKET_WALL;
N20_BRACKET_HEIGHT  = N20_BODY_DIA + 2 * N20_BRACKET_WALL;
N20_BRACKET_LENGTH  = N20_MOUNT_DEPTH + N20_BRACKET_WALL;

// --- Hull attachment (M4 bolts) ---
BOLT_COUNT          = 8;     // More bolts for longer plate
BOLT_SPACING        = (SIDE_PLATE_LENGTH - 40) / (BOLT_COUNT - 1);
BOLT_X_START        = 20;
BOLT_Z              = SIDE_PLATE_HEIGHT - 8;
M4_HOLE_DIA         = 4.4;

// --- Hull width for assembly ---
HULL_W = 203;   // 1:18 scale hull width

// --- Aesthetic ---
PANEL_LINE_SPACING  = 25;
PANEL_LINE_DEPTH    = 0.2;
PANEL_LINE_WIDTH    = 0.3;
RETURN_ROLLER_DIA   = 10;
RETURN_ROLLER_THICK = 8;
TOP_CHAMFER         = 0.5;
WHEEL_SHADOW_GAP    = 0.15;

// =====================================================================
// MODULES
// =====================================================================

module road_wheel() {
    difference() {
        cylinder(d=ROAD_WHEEL_DIA, h=ROAD_WHEEL_THICK, center=true);
        cylinder(d=ROAD_WHEEL_AXLE_DIA, h=ROAD_WHEEL_THICK+1, center=true);
        // Center groove for track center guide
        translate([0, 0, 0])
            difference() {
                cylinder(d=ROAD_WHEEL_DIA+1, h=3, center=true);
                cylinder(d=ROAD_WHEEL_DIA-4, h=4, center=true);
            }
    }
    // Hub boss
    translate([0, 0, ROAD_WHEEL_THICK/2])
        cylinder(d=6, h=1, $fn=32);
    // Bolt detail
    for (a = [0:90:270])
        rotate([0, 0, a])
            translate([4, 0, ROAD_WHEEL_THICK/2])
                cylinder(d=1.5, h=0.5, $fn=12);
}

module drive_sprocket() {
    difference() {
        union() {
            cylinder(d=SPROCKET_DIA, h=SPROCKET_THICK, center=true);
            for (i = [0:SPROCKET_TEETH-1])
                rotate([0, 0, i * 360/SPROCKET_TEETH])
                    translate([SPROCKET_DIA/2, 0, 0])
                        cylinder(d1=5, d2=2, h=SPROCKET_THICK, center=true, $fn=3);
        }
        cylinder(d=SPROCKET_SHAFT_DIA, h=SPROCKET_THICK+1, center=true);
        // D-flat
        translate([SPROCKET_SHAFT_DIA/2 + 0.3, 0, 0])
            cube([1, SPROCKET_SHAFT_DIA, SPROCKET_THICK+1], center=true);
    }
}

module idler_wheel() {
    difference() {
        cylinder(d=IDLER_DIA, h=IDLER_THICK, center=true);
        cylinder(d=IDLER_AXLE_DIA, h=IDLER_THICK+1, center=true);
    }
}

module return_roller() {
    translate([SIDE_PLATE_LENGTH/2, -RETURN_ROLLER_THICK/2, SIDE_PLATE_HEIGHT])
        rotate([90, 0, 0])
            difference() {
                cylinder(d=RETURN_ROLLER_DIA, h=RETURN_ROLLER_THICK, center=true);
                cylinder(d=ROAD_WHEEL_AXLE_DIA, h=RETURN_ROLLER_THICK+1, center=true);
            }
}

module track_guide_rail() {
    cube([SIDE_PLATE_LENGTH, RAIL_WIDTH, RAIL_HEIGHT]);
}

module tension_slot_through() {
    hull() {
        cylinder(d=IDLER_AXLE_DIA+0.4, h=SIDE_PLATE_WALL+0.2, center=true);
        translate([IDLER_SLOT_LENGTH, 0, 0])
            cylinder(d=IDLER_AXLE_DIA+0.4, h=SIDE_PLATE_WALL+0.2, center=true);
    }
}

module n20_motor_mount_positioned() {
    difference() {
        translate([-(N20_BRACKET_LENGTH-N20_BRACKET_WALL), 0, -N20_BRACKET_HEIGHT/2])
            cube([N20_BRACKET_LENGTH, N20_MOUNT_DEPTH+N20_BRACKET_WALL, N20_BRACKET_HEIGHT]);
        // Motor bore
        translate([-(N20_MOUNT_DEPTH+0.05), (N20_MOUNT_DEPTH+N20_BRACKET_WALL)/2, 0])
            rotate([90, 0, 0])
                translate([0, 0, -(N20_MOUNT_DEPTH+N20_BRACKET_WALL)/2])
                    cylinder(d=N20_BODY_DIA, h=N20_MOUNT_DEPTH+0.1);
        // Shaft pass-through
        translate([0.05, (N20_MOUNT_DEPTH+N20_BRACKET_WALL)/2, 0])
            rotate([0, -90, 0])
                cylinder(d=SPROCKET_SHAFT_DIA+1, h=N20_BRACKET_LENGTH+0.2);
    }
}

// =====================================================================
// TRACK BELT (rectangular loop)
// =====================================================================

module track_belt() {
    t = TRACK_BELT_THICK;
    rw_bottom = ROAD_WHEEL_Z - ROAD_WHEEL_DIA/2;
    belt_z = rw_bottom - t;
    top_z = SIDE_PLATE_HEIGHT - 3;
    front_x = IDLER_X - IDLER_DIA/2 - 2;
    rear_x = SPROCKET_X + SPROCKET_DIA/2 + SPROCKET_TOOTH_H + 2;
    belt_w = TRACK_BELT_WIDTH;
    belt_y = -(belt_w/2);

    // Bottom (ground contact)
    translate([front_x, belt_y, belt_z])
        cube([rear_x - front_x, belt_w, t]);
    // Top (return)
    translate([front_x, belt_y, top_z])
        cube([rear_x - front_x, belt_w, t]);
    // Front wrap
    translate([front_x - t, belt_y, belt_z])
        cube([t, belt_w, top_z + t - belt_z]);
    // Rear wrap
    translate([rear_x, belt_y, belt_z])
        cube([t, belt_w, top_z + t - belt_z]);
}

// =====================================================================
// SIDE PLATE (watertight manifold)
// =====================================================================

module side_plate_left() {
    difference() {
        union() {
            // Main box
            difference() {
                cube([SIDE_PLATE_LENGTH, SIDE_PLATE_WIDTH, SIDE_PLATE_HEIGHT]);
                translate([SIDE_PLATE_WALL, SIDE_PLATE_WALL, SIDE_PLATE_WALL])
                    cube([
                        SIDE_PLATE_LENGTH - 2*SIDE_PLATE_WALL,
                        SIDE_PLATE_WIDTH - 2*SIDE_PLATE_WALL,
                        SIDE_PLATE_HEIGHT - 2*SIDE_PLATE_WALL
                    ]);
            }

            // Track guide rails on inner face
            translate([0, SIDE_PLATE_WIDTH - RAIL_WIDTH, SIDE_PLATE_WALL])
                track_guide_rail();
            translate([0, SIDE_PLATE_WIDTH - RAIL_WIDTH, SIDE_PLATE_HEIGHT - SIDE_PLATE_WALL - RAIL_HEIGHT])
                track_guide_rail();

            // N20 motor mount at rear
            translate([SIDE_PLATE_LENGTH - N20_BRACKET_WALL, SIDE_PLATE_WIDTH, SPROCKET_Z])
                n20_motor_mount_positioned();
        }

        // Panel line grooves
        groove_count = floor(SIDE_PLATE_LENGTH / PANEL_LINE_SPACING);
        for (i = [1:groove_count-1])
            translate([i*PANEL_LINE_SPACING, -0.01, SIDE_PLATE_WALL])
                cube([PANEL_LINE_WIDTH, PANEL_LINE_DEPTH+0.01, SIDE_PLATE_HEIGHT - 2*SIDE_PLATE_WALL]);

        // Top edge chamfer
        translate([-0.01, -0.01, SIDE_PLATE_HEIGHT - TOP_CHAMFER])
            rotate([45, 0, 0])
                cube([SIDE_PLATE_LENGTH+0.02, TOP_CHAMFER*1.5, TOP_CHAMFER*1.5]);

        // M4 bolt holes for hull attachment
        for (i = [0:BOLT_COUNT-1])
            translate([BOLT_X_START + i*BOLT_SPACING, SIDE_PLATE_WIDTH - 0.05, BOLT_Z])
                rotate([-90, 0, 0])
                    rotate([180, 0, 0])
                        cylinder(d=M4_HOLE_DIA, h=SIDE_PLATE_WALL+0.1);

        // Road wheel axle holes
        for (i = [0:ROAD_WHEEL_COUNT-1])
            translate([ROAD_WHEEL_X_START + i*ROAD_WHEEL_SPACING, -0.05, ROAD_WHEEL_Z])
                rotate([-90, 0, 0])
                    cylinder(d=ROAD_WHEEL_AXLE_DIA+0.4, h=SIDE_PLATE_WALL+0.1);

        // Sprocket axle hole
        translate([SPROCKET_X, -0.05, SPROCKET_Z])
            rotate([-90, 0, 0])
                cylinder(d=SPROCKET_SHAFT_DIA+0.4, h=SIDE_PLATE_WALL+0.1);

        // Idler tension slot
        translate([IDLER_X - IDLER_SLOT_LENGTH/2, SIDE_PLATE_WALL/2, IDLER_Z])
            rotate([90, 0, 0])
                tension_slot_through();
    }
}

// =====================================================================
// FULL TRACK ASSEMBLY
// =====================================================================

module track_assembly_v2_left() {
    // Side plate
    side_plate_left();

    // Return roller
    return_roller();

    // Road wheels
    for (i = [0:ROAD_WHEEL_COUNT-1])
        translate([ROAD_WHEEL_X_START + i*ROAD_WHEEL_SPACING,
                   -(ROAD_WHEEL_THICK/2 + WHEEL_SHADOW_GAP), ROAD_WHEEL_Z])
            rotate([90, 0, 0])
                road_wheel();

    // Drive sprocket (rear)
    translate([SPROCKET_X, -SPROCKET_THICK/2, SPROCKET_Z])
        rotate([90, 0, 0])
            drive_sprocket();

    // Idler wheel (front)
    translate([IDLER_X, -IDLER_THICK/2, IDLER_Z])
        rotate([90, 0, 0])
            idler_wheel();

    // Track belt
    color("#2a2a2a")
        track_belt();
}

module track_assembly_v2_right() {
    translate([0, HULL_W + 2*SIDE_PLATE_WIDTH, 0])
        mirror([0, 1, 0])
            track_assembly_v2_left();
}

// =====================================================================
// SIDE PLATE BOLT TAB (solid material at split seams)
// =====================================================================
module plate_bolt_tab() {
    difference() {
        translate([-PLATE_BOLT_TAB_D/2, -PLATE_BOLT_TAB_W/2, -PLATE_BOLT_TAB_H/2])
            cube([PLATE_BOLT_TAB_D, PLATE_BOLT_TAB_W, PLATE_BOLT_TAB_H]);
        rotate([0, 90, 0])
            cylinder(d=PLATE_BOLT_DIA, h=PLATE_BOLT_TAB_D + 2, center=true);
    }
}

// =====================================================================
// SPLIT SIDE PLATE SEGMENTS (each fits 180x180mm bed)
// =====================================================================

// Front segment: X = 0 to PLATE_FRONT_LEN (134mm)
module side_plate_front() {
    difference() {
        intersection() {
            side_plate_left();
            cube([PLATE_FRONT_LEN, SIDE_PLATE_WIDTH + 50, SIDE_PLATE_HEIGHT + 50]);
        }
        // Bolt holes at rear seam
        for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
            translate([PLATE_FRONT_LEN, SIDE_PLATE_WIDTH / 2, bz])
                rotate([0, 90, 0])
                    cylinder(d=PLATE_BOLT_DIA, h=PLATE_BOLT_TAB_D + 2, center=true);
        }
    }
    // Bolt tabs at rear seam
    for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
        translate([PLATE_FRONT_LEN, SIDE_PLATE_WIDTH / 2, bz])
            plate_bolt_tab();
    }
}

// Mid segment: X = PLATE_FRONT_LEN to PLATE_FRONT_LEN + PLATE_MID_LEN (134..267mm)
module side_plate_mid() {
    mid_start = PLATE_FRONT_LEN;
    mid_end = PLATE_FRONT_LEN + PLATE_MID_LEN;
    difference() {
        intersection() {
            side_plate_left();
            translate([mid_start, 0, 0])
                cube([PLATE_MID_LEN, SIDE_PLATE_WIDTH + 50, SIDE_PLATE_HEIGHT + 50]);
        }
        // Bolt holes at front seam
        for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
            translate([mid_start, SIDE_PLATE_WIDTH / 2, bz])
                rotate([0, 90, 0])
                    cylinder(d=PLATE_BOLT_DIA, h=PLATE_BOLT_TAB_D + 2, center=true);
        }
        // Bolt holes at rear seam
        for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
            translate([mid_end, SIDE_PLATE_WIDTH / 2, bz])
                rotate([0, 90, 0])
                    cylinder(d=PLATE_BOLT_DIA, h=PLATE_BOLT_TAB_D + 2, center=true);
        }
    }
    // Bolt tabs at both seams
    for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
        translate([mid_start, SIDE_PLATE_WIDTH / 2, bz])
            plate_bolt_tab();
        translate([mid_end, SIDE_PLATE_WIDTH / 2, bz])
            plate_bolt_tab();
    }
}

// Rear segment: X = PLATE_FRONT_LEN + PLATE_MID_LEN to SIDE_PLATE_LENGTH (267..400mm)
module side_plate_rear() {
    rear_start = PLATE_FRONT_LEN + PLATE_MID_LEN;
    difference() {
        intersection() {
            side_plate_left();
            translate([rear_start, 0, 0])
                cube([PLATE_REAR_LEN, SIDE_PLATE_WIDTH + 50, SIDE_PLATE_HEIGHT + 50]);
        }
        // Bolt holes at front seam
        for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
            translate([rear_start, SIDE_PLATE_WIDTH / 2, bz])
                rotate([0, 90, 0])
                    cylinder(d=PLATE_BOLT_DIA, h=PLATE_BOLT_TAB_D + 2, center=true);
        }
    }
    // Bolt tabs at front seam
    for (bz = [SIDE_PLATE_HEIGHT * 0.3, SIDE_PLATE_HEIGHT * 0.7]) {
        translate([rear_start, SIDE_PLATE_WIDTH / 2, bz])
            plate_bolt_tab();
    }
}

// =====================================================================
// PART SELECTOR
// =====================================================================

if (part == "left") {
    track_assembly_v2_left();
} else if (part == "right") {
    mirror([0, 1, 0])
        track_assembly_v2_left();
} else if (part == "sprocket") {
    drive_sprocket();
} else if (part == "plate_front") {
    side_plate_front();
} else if (part == "plate_mid") {
    side_plate_mid();
} else if (part == "plate_rear") {
    side_plate_rear();
} else if (part == "assembly") {
    track_assembly_v2_left();
    track_assembly_v2_right();
}
