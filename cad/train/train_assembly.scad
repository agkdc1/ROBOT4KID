// NL2Bot Shinkansen N700 — Full Assembly Visualization
// Use this file to preview the complete train with all components
// Locomotive: 130x36x30mm (Plarail compatible)
// Motor mount at rear, battery bay center, camera mount in nose

include <../libs/common.scad>     // include (not use) to get variables
use <../libs/electronics.scad>
use <locomotive.scad>
use <motor_mount.scad>
use <battery_bay.scad>
use <camera_mount.scad>

// --- Locomotive Dimensions (from locomotive.scad) ---
loco_length       = 130;           // BODY_LENGTH
loco_width        = 36;            // BODY_WIDTH
loco_height       = 30;            // BODY_HEIGHT
loco_main_length  = 102;           // BODY_MAIN_LENGTH (130 - 28 nose)
nose_length       = 28;            // NOSE_LENGTH (longer for aerodynamic taper)
wall              = 1.6;           // WALL (increased for structural integrity)
shell_split_z     = 14;            // Split line height

// --- Axle Positions (from locomotive.scad wheel_bosses) ---
axle_x_rear       = 15;
wheel_spacing     = 30;
axle_x_front      = axle_x_rear + wheel_spacing;  // 45

// --- Motor Mount Dimensions ---
// Motor cradle is Y-centered, motor shaft extends in +Y direction
// MOUNT_WIDTH ~16.4, MOUNT_LENGTH ~33, MOUNT_HEIGHT ~11
// We need to rotate 90deg so motor shaft aligns with X-axis (toward rear axle)
// Motor drives the rear axle
motor_mount_z     = wall;          // Sits on floor of bottom shell

// --- Battery Bay Dimensions ---
// OUTER_L ~86.6mm, OUTER_W ~25.6mm, CRADLE_H ~13mm
// Origin at corner (0,0,0), extends +X, +Y
batt_outer_l      = 77 + 2*0.3 + 5 + 2*2;  // ~86.6
batt_outer_w      = 21 + 2*0.3 + 2*2;       // ~25.6
batt_bay_z        = wall;          // Sits on floor

// --- Camera Mount Dimensions ---
// Total footprint ~49.6 x 33.6mm, origin at corner
cam_inner_l       = 40 + 2*0.3;   // 40.6
cam_rail_w        = 3;
cam_total_l       = cam_inner_l + 2*cam_rail_w;  // ~46.6
cam_total_w       = 27 + 2*0.3 + 2*cam_rail_w;  // ~33.6
cam_mount_z       = wall;          // Sits on floor

// =====================================================================
// Locomotive Body (bottom + top shell)
// =====================================================================
// Bottom shell (opaque body color)
color("LightGray")
    bottom_shell();

// Top shell (translucent for visibility into interior)
color("White", 0.7)
    top_shell();

// =====================================================================
// Motor Mount — Rear Section
// =====================================================================
// Motor mount cradle is Y-centered with motor shaft in +Y direction.
// Rear axle is at X=15, perpendicular to body (runs in Y direction).
// Motor shaft needs to point toward axle, so we rotate mount -90deg
// around Z so motor shaft points in +X, then position at rear.
// The mount extends: X = [-cable_channel..mount_length+bearing], Y-centered
// After rotation: motor shaft faces +X toward axle
color("SteelBlue", 0.85)
translate([axle_x_rear, 0, motor_mount_z])
    rotate([0, 0, -90])
        train_motor_mount();

// =====================================================================
// Battery Bay — Center Section
// =====================================================================
// Battery bay origin is at its corner. Center it in the body.
// X: center of rectangular section = loco_main_length/2
// Y: center on body centerline (body is Y-centered)
color("Gold", 0.85)
translate([loco_main_length/2 - batt_outer_l/2,
           -batt_outer_w/2,
           batt_bay_z])
    train_battery_bay();

// =====================================================================
// Camera Mount — Nose Section
// =====================================================================
// Camera mount origin is at back-left corner.
// Lens faces +X (forward through the nose).
// Position at front of main body, inside the nose cavity.
// The nose starts at X = loco_main_length (102mm).
// Camera mount ~46.6mm long, place it so lens aligns with nose.
color("LimeGreen", 0.85)
translate([loco_main_length - 5,
           -cam_total_w/2,
           cam_mount_z])
    train_camera_mount();

// =====================================================================
// Ghost Volumes — Electronic Components for Reference
// =====================================================================
// ESP32-CAM in nose (via locomotive ghost)
cam_x = loco_main_length - 5;
%translate([cam_x + cam_rail_w + 0.3, -27/2, wall + 4])
    esp32cam_dummy();

// 18650 battery in center
batt_x = loco_main_length/2 - 77/2;
%translate([batt_x, -21/2, wall + 2])
    battery_holder_1cell_dummy();

// N20 motor in rear
%translate([5, 0, wall + 3])
    rotate([0, 90, 0])
        n20_motor_dummy();

// =====================================================================
// Wheels — Plarail-compatible, VERTICAL orientation (rotate around Y-axis)
// =====================================================================
// Wheels are cylinders standing upright, axle runs in Y direction
wheel_dia = 10;       // Plarail wheel diameter
wheel_t   = 3;        // Wheel thickness
track_gauge_half = 27 / 2;  // Half of Plarail track gauge
wheel_z = -wheel_dia / 2;   // Bottom of wheel at ground level

color("#333333")
for (ax = [axle_x_rear, axle_x_front]) {
    for (side = [-1, 1]) {
        y_pos = side * (track_gauge_half + wheel_t / 2);
        translate([ax, y_pos, 0])
            rotate([90, 0, 0])  // Rotate so cylinder axis = Y (horizontal axle)
                cylinder(h = wheel_t, d = wheel_dia, center = true, $fn = 32);
    }
}

// =====================================================================
// Ground Plane (visual reference)
// =====================================================================
color("#3a3a3a", 0.3)
translate([-20, -40, -2])
    cube([180, 80, 0.5]);

// =====================================================================
$fn = 64;
