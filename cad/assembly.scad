// M1A1 Abrams — Full Assembly Visualization
// Use this file to preview the complete tank with all components
// Includes: hull, turret, barrel, tracks, electronics bay, sensors

include <libs/common.scad>     // include (not use) to get variables
use <libs/electronics.scad>
use <chassis/hull.scad>
use <chassis/track_assembly.scad>
use <chassis/electronics_bay.scad>
use <turret/turret_body.scad>
use <turret/gun_barrel.scad>

// --- Assembly Parameters ---
// Hull turret ring center: X = 150+75 = 225, Y = 45 (HULL_WIDTH/2)
turret_ring_cx = 150 + 75;      // X center of turret ring on hull
turret_ring_cy = HULL_WIDTH / 2; // Y center
turret_cx = 60;                  // turret_length / 2
turret_cy = 47.5;               // turret_width / 2

// --- Hull (at origin) ---
color("#5a6e3a")
hull_assembly();

// --- Tracks (both sides, 2 per side to cover full 300mm hull) ---
// Each track assembly is 150mm. Place front + rear on each side.
color("#4a4a3a")
// Left side — front track
translate([0, -TRACK_WIDTH, 0])
    track_assembly_left();
// Left side — rear track
translate([150, -TRACK_WIDTH, 0])
    track_assembly_left();
// Right side — front track (mirrored)
translate([0, HULL_WIDTH + TRACK_WIDTH, 0])
    mirror([0, 1, 0]) track_assembly_left();
// Right side — rear track (mirrored)
translate([150, HULL_WIDTH + TRACK_WIDTH, 0])
    mirror([0, 1, 0]) track_assembly_left();

// --- Electronics bay (inside rear hull) ---
color("#2a3a2a", 0.6)
translate([150 + (150 - 138)/2, (HULL_WIDTH - 86)/2, 1.6])
    assembly();

// --- Turret (on top of hull, no rotation needed) ---
// Gun trunnion is now at turret local X=15 (front end, same as cheek armor).
// Turret X=0 (front/cheek) faces toward lower global X = front of tank.
// Place turret so its center aligns with hull turret ring center.
color("#4a5e2a")
translate([turret_ring_cx - turret_cx, turret_ring_cy - turret_cy, TANK_HEIGHT])
    turret_body();

// --- Gun barrel ---
// Trunnion at turret local [15, 47.5, 30]
// Global = [225-60+15, 45-47.5+47.5, 80+30] = [180, 45, 110]
// Barrel built along +Z. Rotate to point toward -X (front of tank).
// rotate([0, -85, 0]): Z rotates toward -X, 5° elevation
color("#3a4e1a")
translate([180, 45, 110])
    rotate([0, -85, 0])
        gun_barrel();

// --- Hull camera (ESP32-CAM at front) ---
color("DarkGreen", 0.8)
translate([3, HULL_WIDTH/2 - 13.5, TANK_HEIGHT * 0.5 + 5])
    esp32cam_dummy();

// --- Turret camera (inside turret front, behind window) ---
// Turret front at global X = 225-60 = 165. Camera at turret local [10, 34, 22]
color("ForestGreen", 0.8)
translate([165 + 10, 45 - 47.5 + 34, TANK_HEIGHT + 22])
    esp32cam_dummy();

// --- VL53L1X ToF (turret front, below camera) ---
color("Cyan", 0.8)
translate([165 + 15, 45 - 47.5 + 38.5, TANK_HEIGHT + 12.5])
    vl53l1x_dummy();
