// NL2Bot Train — N20 Motor Mount for Plarail Locomotive
// Integrates into bottom shell rear, drives rear axle
// All dimensions in millimeters

use <../libs/common.scad>
use <../libs/electronics.scad>

// --- Plarail Parameters (match locomotive.scad) ---
TRACK_GAUGE        = 27;
AXLE_DIA           = 2.0;
AXLE_HOLE_DIA      = AXLE_DIA + PRINT_TOLERANCE * 2;

// --- Motor Orientation ---
// Motor sits longitudinally, shaft pointing toward rear axle
// Worm gear on motor shaft meshes with gear on axle
MOTOR_OFFSET_Z     = 3;     // Height of motor center above floor
MOUNT_WALL         = 2.0;   // Mount wall thickness

// --- Worm Gear Parameters ---
WORM_DIA           = 6;     // Worm gear OD on motor shaft
WORM_LENGTH        = 8;     // Worm gear length
DRIVEN_GEAR_DIA    = 12;    // Spur gear on axle
GEAR_MESH_GAP      = 0.3;   // Gap between worm and driven gear

// --- Motor Cable Channel ---
CABLE_CHANNEL_W    = 6;     // Width for motor wires
CABLE_CHANNEL_D    = 3;     // Depth of cable channel
CABLE_CHANNEL_L    = 30;    // Length to DRV8833 zone

// --- Mount Dimensions ---
MOUNT_LENGTH       = N20_BODY_LEN + 8;  // Motor body + retention
MOUNT_WIDTH        = N20_BODY_DIA + 2 * MOUNT_WALL + ELEC_CLEARANCE;
MOUNT_HEIGHT       = N20_BODY_DIA / 2 + MOUNT_WALL + MOTOR_OFFSET_Z;

// =====================================================================
// Motor Cradle (clamp-style, bottom half)
// =====================================================================
module motor_cradle() {
    motor_r = (N20_BODY_DIA + ELEC_CLEARANCE) / 2;

    difference() {
        union() {
            // Base block
            translate([-MOUNT_WIDTH/2, 0, 0])
                cube([MOUNT_WIDTH, MOUNT_LENGTH, MOUNT_HEIGHT]);

            // Rear retention wall (behind motor)
            translate([-MOUNT_WIDTH/2, -MOUNT_WALL, 0])
                cube([MOUNT_WIDTH, MOUNT_WALL, MOUNT_HEIGHT + motor_r]);

            // Side clamp walls (extend above motor center for grip)
            for (x_sign = [-1, 1]) {
                translate([x_sign * (motor_r + MOUNT_WALL/2) - MOUNT_WALL/2,
                           0, 0])
                    cube([MOUNT_WALL, MOUNT_LENGTH * 0.7,
                          MOTOR_OFFSET_Z + motor_r + MOUNT_WALL]);
            }
        }

        // Motor bore (cylindrical cavity)
        translate([0, -MOUNT_WALL - 0.05, MOTOR_OFFSET_Z])
            rotate([-90, 0, 0])
                cylinder(h=N20_BODY_LEN + MOUNT_WALL + 0.1, d=N20_BODY_DIA + ELEC_CLEARANCE);

        // Shaft exit hole (through front wall area)
        translate([0, MOUNT_LENGTH - 0.05, MOTOR_OFFSET_Z])
            rotate([-90, 0, 0])
                cylinder(h=MOUNT_WALL + 0.1, d=N20_SHAFT_DIA + 1);

        // Wire exit slot (bottom rear for solder terminals)
        translate([-CABLE_CHANNEL_W/2, -MOUNT_WALL - 0.05, 0])
            cube([CABLE_CHANNEL_W, MOUNT_WALL + 0.1, MOTOR_OFFSET_Z]);
    }
}

// =====================================================================
// Axle Bearing Block
// =====================================================================
module axle_bearing(height=8) {
    bearing_od = 6;

    difference() {
        // Outer bearing block
        translate([-bearing_od/2, -bearing_od/2, 0])
            cube([bearing_od, bearing_od, height]);
        // Axle hole
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=AXLE_HOLE_DIA);
    }
}

// =====================================================================
// Cable Routing Channel
// =====================================================================
module cable_channel() {
    // Open-top channel from motor to DRV8833 zone
    wall = 1.2;

    difference() {
        translate([-CABLE_CHANNEL_W/2 - wall, 0, 0])
            cube([CABLE_CHANNEL_W + 2*wall, CABLE_CHANNEL_L, CABLE_CHANNEL_D + wall]);
        translate([-CABLE_CHANNEL_W/2, -0.05, wall])
            cube([CABLE_CHANNEL_W, CABLE_CHANNEL_L + 0.1, CABLE_CHANNEL_D + 0.1]);
    }
}

// =====================================================================
// Complete Motor Mount Assembly
// =====================================================================
module train_motor_mount() {
    // Motor cradle
    motor_cradle();

    // Axle bearing blocks (at rear axle position, both sides)
    translate([0, MOUNT_LENGTH + 2, 0]) {
        // Left bearing
        translate([-TRACK_GAUGE/2, 0, 0])
            axle_bearing();
        // Right bearing
        translate([TRACK_GAUGE/2, 0, 0])
            axle_bearing();
    }

    // Cable routing channel (extends forward from motor)
    translate([0, -MOUNT_WALL - CABLE_CHANNEL_L, 0])
        cable_channel();
}

// =====================================================================
// Render
// =====================================================================
train_motor_mount();

// Ghost: motor dummy for reference
%translate([0, 0, MOTOR_OFFSET_Z])
    rotate([-90, 0, 0])
        rotate([0, 0, 0])
            translate([0, 0, 0]) {
                cylinder(h=N20_BODY_LEN, d=N20_BODY_DIA);
                translate([0, 0, N20_BODY_LEN])
                    cylinder(h=N20_SHAFT_LEN, d=N20_SHAFT_DIA);
            }

$fn = 64;
