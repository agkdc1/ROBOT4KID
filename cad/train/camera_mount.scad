// NL2Bot Train — ESP32-CAM Mount for Shinkansen Nose
// Tilted cradle with lens aperture, fits inside nose cone
// All dimensions in millimeters

use <../libs/common.scad>
use <../libs/electronics.scad>

// --- Camera Dimensions (from electronics.scad) ---
// ESP32CAM_L = 40mm, ESP32CAM_W = 27mm, ESP32CAM_H = 12mm
// ESP32CAM_LENS_DIA = 8mm, ESP32CAM_LENS_PROTRUDE = 4mm

// --- Mount Parameters ---
TILT_ANGLE         = 10;        // Downward tilt for better track view
MOUNT_WALL         = 2.0;       // Cradle wall thickness
MOUNT_TOLERANCE    = 0.3;       // Fit tolerance
RAIL_H_EXTRA       = 3;         // Rail height above board level

// --- Antenna Clearance ---
ANTENNA_CLEAR_L    = 15;        // Clearance behind board for PCB antenna
ANTENNA_CLEAR_H    = 10;        // Height clearance for antenna

// --- Lens Aperture ---
LENS_APERTURE_DIA  = ESP32CAM_LENS_DIA + 3;  // Generous aperture
LENS_RING_WALL     = 2;         // Ring around aperture

// --- Wire Exit ---
WIRE_EXIT_W        = 10;        // Wire exit slot width
WIRE_EXIT_H        = 5;         // Wire exit slot height

// --- Computed Dimensions ---
INNER_L            = ESP32CAM_L + 2 * MOUNT_TOLERANCE;
INNER_W            = ESP32CAM_W + 2 * MOUNT_TOLERANCE;
RAIL_W             = 3;         // Side rail width
CRADLE_H           = ESP32CAM_H + RAIL_H_EXTRA;
BASE_THICKNESS     = 2;         // Base plate thickness

// =====================================================================
// Camera Cradle (side-rail style)
// =====================================================================
module camera_cradle() {
    difference() {
        union() {
            // Base plate
            cube([INNER_L + 2*RAIL_W, INNER_W + 2*RAIL_W, BASE_THICKNESS]);

            // Left side rail
            cube([INNER_L + 2*RAIL_W, RAIL_W, BASE_THICKNESS + CRADLE_H]);

            // Right side rail
            translate([0, RAIL_W + INNER_W, 0])
                cube([INNER_L + 2*RAIL_W, RAIL_W, BASE_THICKNESS + CRADLE_H]);

            // Back stop wall
            cube([RAIL_W, INNER_W + 2*RAIL_W, BASE_THICKNESS + CRADLE_H]);

            // Front retaining lip (partial, leaving lens area open)
            lip_w = (INNER_W + 2*RAIL_W - LENS_APERTURE_DIA - 2*LENS_RING_WALL) / 2;
            translate([RAIL_W + INNER_L, 0, 0])
                cube([RAIL_W, lip_w, BASE_THICKNESS + CRADLE_H]);
            translate([RAIL_W + INNER_L, INNER_W + 2*RAIL_W - lip_w, 0])
                cube([RAIL_W, lip_w, BASE_THICKNESS + CRADLE_H]);
        }

        // Lens aperture through front wall
        translate([RAIL_W + INNER_L - 0.05,
                   RAIL_W + INNER_W/2,
                   BASE_THICKNESS + ESP32CAM_H - ESP32CAM_LENS_DIA/2 - 1])
            rotate([0, 90, 0])
                cylinder(h=RAIL_W * 2 + 0.1, d=LENS_APERTURE_DIA);

        // Wire exit slot through back wall
        translate([-0.05,
                   RAIL_W + INNER_W/2 - WIRE_EXIT_W/2,
                   BASE_THICKNESS])
            cube([RAIL_W + 0.1, WIRE_EXIT_W, WIRE_EXIT_H]);
    }
}

// =====================================================================
// Antenna Clearance Notch
// =====================================================================
module antenna_clearance() {
    // Open area behind the board for PCB antenna radiation
    // The back wall has a notch at the top
    translate([-0.05,
               RAIL_W + 2,
               BASE_THICKNESS + ESP32CAM_H - 2])
        cube([RAIL_W + 0.1, INNER_W - 4, ANTENNA_CLEAR_H]);
}

// =====================================================================
// Lens Shroud (light baffle ring)
// =====================================================================
module lens_shroud() {
    // Short tube protruding forward to block stray light
    shroud_length = 3;

    translate([RAIL_W + INNER_L + RAIL_W,
               RAIL_W + INNER_W/2,
               BASE_THICKNESS + ESP32CAM_H - ESP32CAM_LENS_DIA/2 - 1])
        rotate([0, 90, 0])
            difference() {
                cylinder(h=shroud_length, d=LENS_APERTURE_DIA + 2*LENS_RING_WALL);
                translate([0, 0, -0.05])
                    cylinder(h=shroud_length + 0.1, d=LENS_APERTURE_DIA);
            }
}

// =====================================================================
// Tilted Mount Base (for integration into nose cone)
// =====================================================================
module tilted_base() {
    // Wedge that tilts the entire cradle downward
    total_w = INNER_W + 2*RAIL_W;
    total_l = INNER_L + 2*RAIL_W + 3;  // +3 for shroud
    tilt_rise = total_l * sin(TILT_ANGLE);

    // Wedge under the cradle
    hull() {
        // Front edge (lower, tilted down)
        translate([total_l, 0, 0])
            cube([0.01, total_w, 1]);
        // Back edge (higher)
        cube([0.01, total_w, tilt_rise + 1]);
    }
}

// =====================================================================
// Complete Camera Mount
// =====================================================================
module train_camera_mount() {
    total_w = INNER_W + 2*RAIL_W;
    total_l = INNER_L + 2*RAIL_W;
    tilt_rise = total_l * sin(TILT_ANGLE);

    // Tilted base wedge
    tilted_base();

    // Camera cradle, tilted
    translate([0, 0, tilt_rise + 1])
        rotate([0, TILT_ANGLE, 0]) {
            difference() {
                camera_cradle();
                antenna_clearance();
            }
            lens_shroud();
        }
}

// =====================================================================
// Render
// =====================================================================
train_camera_mount();

// Ghost: ESP32-CAM for reference
total_l_ref = INNER_L + 2*RAIL_W;
tilt_rise_ref = total_l_ref * sin(TILT_ANGLE);
%translate([0, 0, tilt_rise_ref + 1])
    rotate([0, TILT_ANGLE, 0])
        translate([RAIL_W + MOUNT_TOLERANCE, RAIL_W + MOUNT_TOLERANCE, BASE_THICKNESS])
            esp32cam_dummy();

$fn = 64;
