// Electronics Component Library for M1A1 Tank Project
// Dummy volumes and mount modules for all electronic components
// All dimensions in millimeters

use <m4_hardware.scad>
use <common.scad>

// --- Print Tolerances ---
ELEC_TOLERANCE = 0.2;           // General fit tolerance
ELEC_CLEARANCE = 0.4;           // Extra clearance for component drop-in

// --- Mounting Hardware ---
M3_HOLE_DIA = 3.4;              // M3 through-hole with clearance
M3_STANDOFF_OD = 6.0;           // M3 standoff outer diameter
M3_STANDOFF_HEIGHT = 5.0;       // Default standoff height

M25_HOLE_DIA = 2.9;             // M2.5 through-hole with clearance
M25_STANDOFF_OD = 5.0;          // M2.5 standoff outer diameter

// --- Wiring Clearance ---
DUPONT_CLEARANCE = 20;          // Vertical clearance above pin headers/terminals

// --- Ghost Volume Color ---
GHOST_ALPHA = 0.15;             // Translucency for clearance zone visualization

// =====================================================================
// 1. ESP32 DevKitC V4
//    Board: 55 x 28 x 13mm, pins extend 8mm below
// =====================================================================
ESP32_L = 55;
ESP32_W = 28;
ESP32_H = 13;
ESP32_PIN_DROP = 8;             // Pin header extension below board

module esp32_dummy() {
    // Board body
    cube([ESP32_L, ESP32_W, ESP32_H]);
    // Pin headers below
    translate([0, 2, -ESP32_PIN_DROP])
        cube([ESP32_L, ESP32_W - 4, ESP32_PIN_DROP]);
    // Dupont clearance ghost above
    %translate([0, 0, ESP32_H])
        cube([ESP32_L, ESP32_W, DUPONT_CLEARANCE]);
}

module esp32_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Cradle with side rails and pin clearance below
    // Board sits on rails, pins hang through center slot
    rail_w = 3;
    rail_h = standoff_h + ESP32_PIN_DROP;
    slot_w = ESP32_W - 2 * rail_w - ELEC_CLEARANCE;

    difference() {
        union() {
            // Left rail
            cube([ESP32_L + ELEC_CLEARANCE, rail_w, rail_h]);
            // Right rail
            translate([0, rail_w + slot_w + ELEC_CLEARANCE, 0])
                cube([ESP32_L + ELEC_CLEARANCE, rail_w, rail_h]);
            // End stops
            cube([rail_w, ESP32_W + ELEC_CLEARANCE, rail_h]);
            translate([ESP32_L + ELEC_CLEARANCE - rail_w, 0, 0])
                cube([rail_w, ESP32_W + ELEC_CLEARANCE, rail_h]);
        }
        // Center slot for pins
        translate([rail_w, rail_w, -0.05])
            cube([ESP32_L - 2 * rail_w, slot_w + ELEC_CLEARANCE, rail_h + 0.1]);
    }
}

// =====================================================================
// 2. Terminal Block Expansion Shield for ESP32
//    85 x 65 x 20mm, M3 holes at corners (76 x 56mm pattern)
// =====================================================================
TERM_SHIELD_L = 85;
TERM_SHIELD_W = 65;
TERM_SHIELD_H = 20;
TERM_SHIELD_MOUNT_X = 76;
TERM_SHIELD_MOUNT_Y = 56;

module terminal_shield_dummy() {
    cube([TERM_SHIELD_L, TERM_SHIELD_W, TERM_SHIELD_H]);
    // Dupont clearance ghost above
    %translate([0, 0, TERM_SHIELD_H])
        cube([TERM_SHIELD_L, TERM_SHIELD_W, DUPONT_CLEARANCE]);
}

module terminal_shield_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Four M3 standoffs at corner pattern
    offset_x = (TERM_SHIELD_L - TERM_SHIELD_MOUNT_X) / 2;
    offset_y = (TERM_SHIELD_W - TERM_SHIELD_MOUNT_Y) / 2;

    positions = [
        [offset_x, offset_y],
        [offset_x + TERM_SHIELD_MOUNT_X, offset_y],
        [offset_x + TERM_SHIELD_MOUNT_X, offset_y + TERM_SHIELD_MOUNT_Y],
        [offset_x, offset_y + TERM_SHIELD_MOUNT_Y]
    ];

    for (p = positions) {
        translate([p[0], p[1], 0])
            difference() {
                cylinder(h=standoff_h, d=M3_STANDOFF_OD);
                translate([0, 0, -0.05])
                    cylinder(h=standoff_h + 0.1, d=M3_HOLE_DIA);
            }
    }
}

// =====================================================================
// 3. ESP32-CAM (AI-Thinker)
//    Board: 40 x 27 x 12mm, camera lens protrudes 4mm at one end
// =====================================================================
ESP32CAM_L = 40;
ESP32CAM_W = 27;
ESP32CAM_H = 12;
ESP32CAM_LENS_PROTRUDE = 4;
ESP32CAM_LENS_DIA = 8;

module esp32cam_dummy() {
    // Main board
    cube([ESP32CAM_L, ESP32CAM_W, ESP32CAM_H]);
    // Camera lens protrusion (centered on end face, at top)
    translate([ESP32CAM_L, ESP32CAM_W / 2, ESP32CAM_H - ESP32CAM_LENS_DIA / 2 - 1])
        rotate([0, 90, 0])
            cylinder(h=ESP32CAM_LENS_PROTRUDE, d=ESP32CAM_LENS_DIA);
    // Dupont clearance ghost above
    %translate([0, 0, ESP32CAM_H])
        cube([ESP32CAM_L, ESP32CAM_W, DUPONT_CLEARANCE]);
}

module esp32cam_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Cradle with side rails and front lens aperture
    rail_w = 3;
    rail_h = standoff_h;
    inner_w = ESP32CAM_W + ELEC_CLEARANCE;
    inner_l = ESP32CAM_L + ELEC_CLEARANCE;

    difference() {
        union() {
            // Left rail
            cube([inner_l, rail_w, rail_h + ESP32CAM_H]);
            // Right rail
            translate([0, rail_w + inner_w, 0])
                cube([inner_l, rail_w, rail_h + ESP32CAM_H]);
            // Back stop
            cube([rail_w, inner_w + 2 * rail_w, rail_h + ESP32CAM_H]);
            // Base plate
            cube([inner_l, inner_w + 2 * rail_w, rail_h]);
        }
        // Lens aperture through front wall (if needed)
        translate([inner_l - 0.05, rail_w + inner_w / 2, rail_h + ESP32CAM_H - ESP32CAM_LENS_DIA / 2 - 1])
            rotate([0, 90, 0])
                cylinder(h=rail_w + 0.1, d=ESP32CAM_LENS_DIA + 2);
    }
}

// =====================================================================
// 4. L298N Dual H-Bridge Motor Driver
//    43 x 43 x 27mm (heatsink), M3 holes at corners (36 x 36mm pattern)
//    Screw terminals on 2 sides, 15mm terminal clearance
// =====================================================================
L298N_L = 43;
L298N_W = 43;
L298N_H = 27;
L298N_MOUNT_SPACING = 36;
L298N_TERM_CLEARANCE = 15;

module l298n_dummy() {
    // Main body with heatsink
    cube([L298N_L, L298N_W, L298N_H]);
    // Terminal clearance on two sides (front and back)
    %translate([-L298N_TERM_CLEARANCE, 0, 0])
        cube([L298N_TERM_CLEARANCE, L298N_W, L298N_H]);
    %translate([L298N_L, 0, 0])
        cube([L298N_TERM_CLEARANCE, L298N_W, L298N_H]);
    // Dupont clearance ghost above
    %translate([-L298N_TERM_CLEARANCE, 0, L298N_H])
        cube([L298N_L + 2 * L298N_TERM_CLEARANCE, L298N_W, DUPONT_CLEARANCE]);
}

module l298n_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Four M3 standoffs at 36x36mm pattern
    offset = (L298N_L - L298N_MOUNT_SPACING) / 2;

    positions = [
        [offset, offset],
        [offset + L298N_MOUNT_SPACING, offset],
        [offset + L298N_MOUNT_SPACING, offset + L298N_MOUNT_SPACING],
        [offset, offset + L298N_MOUNT_SPACING]
    ];

    for (p = positions) {
        translate([p[0], p[1], 0])
            difference() {
                cylinder(h=standoff_h, d=M3_STANDOFF_OD);
                translate([0, 0, -0.05])
                    cylinder(h=standoff_h + 0.1, d=M3_HOLE_DIA);
            }
    }
}

// =====================================================================
// 5. LM2596 Buck Converter
//    43 x 21 x 14mm, 2 M3 holes in line (35mm apart)
// =====================================================================
LM2596_L = 43;
LM2596_W = 21;
LM2596_H = 14;
LM2596_MOUNT_SPACING = 35;

module lm2596_dummy() {
    cube([LM2596_L, LM2596_W, LM2596_H]);
    // Dupont clearance ghost above
    %translate([0, 0, LM2596_H])
        cube([LM2596_L, LM2596_W, DUPONT_CLEARANCE]);
}

module lm2596_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Two M3 standoffs in line along length, centered in width
    offset_x = (LM2596_L - LM2596_MOUNT_SPACING) / 2;
    center_y = LM2596_W / 2;

    for (x = [offset_x, offset_x + LM2596_MOUNT_SPACING]) {
        translate([x, center_y, 0])
            difference() {
                cylinder(h=standoff_h, d=M3_STANDOFF_OD);
                translate([0, 0, -0.05])
                    cylinder(h=standoff_h + 0.1, d=M3_HOLE_DIA);
            }
    }
}

// =====================================================================
// 6. 18650 Battery Holder (2-cell)
//    77 x 41 x 20mm, spring-loaded, no mounting holes — friction cradle
// =====================================================================
BATT_HOLDER_L = 77;
BATT_HOLDER_W = 41;
BATT_HOLDER_H = 20;
BATT_CRADLE_WALL = 2.0;
BATT_CRADLE_LIP = 3.0;         // Retaining lip height

module battery_holder_dummy() {
    cube([BATT_HOLDER_L, BATT_HOLDER_W, BATT_HOLDER_H]);
    // Dupont clearance ghost above (for spring terminals)
    %translate([0, 0, BATT_HOLDER_H])
        cube([BATT_HOLDER_L, BATT_HOLDER_W, DUPONT_CLEARANCE]);
}

module battery_holder_mount() {
    // Friction-fit cradle with retaining lips
    inner_l = BATT_HOLDER_L + ELEC_CLEARANCE;
    inner_w = BATT_HOLDER_W + ELEC_CLEARANCE;
    wall = BATT_CRADLE_WALL;
    outer_l = inner_l + 2 * wall;
    outer_w = inner_w + 2 * wall;
    cradle_h = BATT_HOLDER_H * 0.6;

    difference() {
        union() {
            // Outer cradle walls
            cube([outer_l, outer_w, cradle_h]);
            // Retaining lips at top corners
            for (x = [0, outer_l - wall])
                for (y = [0, outer_w - wall])
                    translate([x, y, cradle_h])
                        cube([wall, wall, BATT_CRADLE_LIP]);
        }
        // Inner cavity
        translate([wall, wall, wall])
            cube([inner_l, inner_w, cradle_h + BATT_CRADLE_LIP + 0.1]);
    }
}

// =====================================================================
// 7. N20 Geared Motor
//    12mm dia x 25mm body, 3mm shaft extends 10mm with D-flat
// =====================================================================
N20_BODY_DIA = 12;
N20_BODY_LEN = 25;
N20_SHAFT_DIA = 3;
N20_SHAFT_LEN = 10;
N20_FLAT_DEPTH = 0.5;           // D-flat cut depth

module n20_motor_dummy() {
    // Motor body
    rotate([0, 90, 0])
        cylinder(h=N20_BODY_LEN, d=N20_BODY_DIA);
    // Output shaft with D-flat
    translate([N20_BODY_LEN, 0, 0])
        rotate([0, 90, 0])
            difference() {
                cylinder(h=N20_SHAFT_LEN, d=N20_SHAFT_DIA);
                translate([N20_SHAFT_DIA / 2 - N20_FLAT_DEPTH, -N20_SHAFT_DIA, 0])
                    cube([N20_SHAFT_DIA, N20_SHAFT_DIA * 2, N20_SHAFT_LEN]);
            }
    // Dupont clearance ghost behind (for solder terminals)
    %translate([-DUPONT_CLEARANCE, -N20_BODY_DIA / 2, -N20_BODY_DIA / 2])
        cube([DUPONT_CLEARANCE, N20_BODY_DIA, N20_BODY_DIA]);
}

module n20_motor_mount(wall=2.0) {
    // Clamp-style motor mount (bottom half cradle)
    clamp_od = N20_BODY_DIA + ELEC_CLEARANCE + 2 * wall;
    clamp_len = N20_BODY_LEN * 0.6;

    difference() {
        // Outer block
        translate([0, -clamp_od / 2, -clamp_od / 2])
            cube([clamp_len, clamp_od, clamp_od / 2 + wall]);
        // Motor bore
        rotate([0, 90, 0])
            cylinder(h=clamp_len + 0.1, d=N20_BODY_DIA + ELEC_CLEARANCE);
        // Shaft exit
        translate([clamp_len - 0.05, -N20_SHAFT_DIA, -N20_SHAFT_DIA])
            cube([wall + 0.1, N20_SHAFT_DIA * 2, N20_SHAFT_DIA * 2]);
    }
}

// =====================================================================
// 8. MPU-6050 (GY-521 breakout)
//    21 x 16 x 3mm PCB, M2.5 mounting holes
// =====================================================================
MPU6050_L = 21;
MPU6050_W = 16;
MPU6050_H = 3;

module mpu6050_dummy() {
    cube([MPU6050_L, MPU6050_W, MPU6050_H]);
    // IC package on top
    translate([MPU6050_L / 2 - 2, MPU6050_W / 2 - 2, MPU6050_H])
        cube([4, 4, 1.2]);
    // Dupont clearance ghost above
    %translate([0, 0, MPU6050_H + 1.2])
        cube([MPU6050_L, MPU6050_W, DUPONT_CLEARANCE]);
}

module mpu6050_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Two M2.5 standoffs along one edge
    hole_offset_x = 2.5;
    hole_y = MPU6050_W / 2;

    for (x = [hole_offset_x, MPU6050_L - hole_offset_x]) {
        translate([x, hole_y, 0])
            difference() {
                cylinder(h=standoff_h, d=M25_STANDOFF_OD);
                translate([0, 0, -0.05])
                    cylinder(h=standoff_h + 0.1, d=M25_HOLE_DIA);
            }
    }
}

// =====================================================================
// 9. VL53L1X ToF Sensor (breakout board)
//    13 x 18 x 4mm, laser aperture at center
// =====================================================================
VL53L1X_L = 13;
VL53L1X_W = 18;
VL53L1X_H = 4;
VL53L1X_APERTURE_DIA = 3;

module vl53l1x_dummy() {
    cube([VL53L1X_L, VL53L1X_W, VL53L1X_H]);
    // Laser aperture indicator
    translate([VL53L1X_L / 2, VL53L1X_W / 2, VL53L1X_H])
        cylinder(h=0.5, d=VL53L1X_APERTURE_DIA);
    // Dupont clearance ghost above
    %translate([0, 0, VL53L1X_H + 0.5])
        cube([VL53L1X_L, VL53L1X_W, DUPONT_CLEARANCE]);
}

module vl53l1x_mount(standoff_h=M3_STANDOFF_HEIGHT) {
    // Simple cradle mount (board is small, no standard mounting holes)
    rail_w = 2;
    inner_l = VL53L1X_L + ELEC_CLEARANCE;
    inner_w = VL53L1X_W + ELEC_CLEARANCE;

    difference() {
        union() {
            // Base plate with aperture hole
            cube([inner_l + 2 * rail_w, inner_w + 2 * rail_w, standoff_h]);
            // Side rails
            cube([inner_l + 2 * rail_w, rail_w, standoff_h + VL53L1X_H]);
            translate([0, rail_w + inner_w, 0])
                cube([inner_l + 2 * rail_w, rail_w, standoff_h + VL53L1X_H]);
        }
        // Laser aperture through base
        translate([rail_w + inner_l / 2, rail_w + inner_w / 2, -0.05])
            cylinder(h=standoff_h + 0.1, d=VL53L1X_APERTURE_DIA + 2);
    }
}

// =====================================================================
// 10. WAGO 221-415 Lever Nut (5-way)
//     20 x 13 x 16mm, for power distribution
// =====================================================================
WAGO_L = 20;
WAGO_W = 13;
WAGO_H = 16;

module wago_dummy() {
    cube([WAGO_L, WAGO_W, WAGO_H]);
    // Wire clearance ghost on both open ends
    %translate([-DUPONT_CLEARANCE, 0, 0])
        cube([DUPONT_CLEARANCE, WAGO_W, WAGO_H]);
    %translate([WAGO_L, 0, 0])
        cube([DUPONT_CLEARANCE, WAGO_W, WAGO_H]);
}

module wago_mount() {
    // Snap-in clip cradle for WAGO connector
    wall = 1.5;
    inner_l = WAGO_L + ELEC_CLEARANCE;
    inner_w = WAGO_W + ELEC_CLEARANCE;
    clip_h = WAGO_H * 0.5;
    lip = 1.0;

    difference() {
        union() {
            // Outer walls
            cube([inner_l + 2 * wall, inner_w + 2 * wall, clip_h]);
            // Retaining lips
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
// Utility Modules
// =====================================================================

module zip_tie_anchor(width=4) {
    // Loop/slot for zip-tie cable management
    slot_w = width + 0.4;        // Zip tie width + clearance
    slot_h = 2.0;                // Zip tie thickness
    wall = 1.5;
    outer_w = slot_w + 2 * wall;
    outer_h = slot_h + 2 * wall;
    depth = 6;

    difference() {
        // Solid block
        cube([depth, outer_w, outer_h]);
        // Zip tie slot (through-hole)
        translate([-0.05, wall, wall])
            cube([depth + 0.1, slot_w, slot_h]);
    }
}

module wire_duct(length, width=10, depth=8) {
    // Open-top channel for routing Dupont wires
    wall = 1.2;

    difference() {
        cube([length, width + 2 * wall, depth]);
        translate([-0.05, wall, wall])
            cube([length + 0.1, width, depth + 0.1]);
    }
}

module slip_ring_void(height=15) {
    // Cylindrical void for turret wire pass-through
    // 22mm diameter to accommodate slip ring or wire bundle
    slip_dia = 22;

    cylinder(h=height, d=slip_dia);
}

// =====================================================================
// M3 Standoff Helper (reusable by other modules)
// =====================================================================

module m3_standoff(height=M3_STANDOFF_HEIGHT) {
    difference() {
        cylinder(h=height, d=M3_STANDOFF_OD);
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=M3_HOLE_DIA);
    }
}

module m25_standoff(height=M3_STANDOFF_HEIGHT) {
    difference() {
        cylinder(h=height, d=M25_STANDOFF_OD);
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=M25_HOLE_DIA);
    }
}

$fn = 64;

// --- Demo ---
// Uncomment to preview all components laid out:
// esp32_dummy();
// translate([70, 0, 0]) terminal_shield_dummy();
// translate([0, 40, 0]) esp32cam_dummy();
// translate([0, 80, 0]) l298n_dummy();
// translate([60, 80, 0]) lm2596_dummy();
// translate([0, 130, 0]) battery_holder_dummy();
// translate([90, 130, 0]) n20_motor_dummy();
// translate([0, 170, 0]) mpu6050_dummy();
// translate([30, 170, 0]) vl53l1x_dummy();
// translate([60, 170, 0]) wago_dummy();
// translate([0, 200, 0]) zip_tie_anchor();
// translate([20, 200, 0]) wire_duct(50);
// translate([80, 200, 0]) slip_ring_void();
