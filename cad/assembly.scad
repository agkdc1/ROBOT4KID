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

// --- Turret (on top of hull, rotated 180° so gun faces front) ---
// The turret module has gun_trunnion at local X=105 (near X=120 end).
// We need the trunnion to face the FRONT of the tank (toward X=0).
// Strategy: translate turret center to turret ring center, rotate 180° around Z.
color("#4a5e2a")
translate([turret_ring_cx, turret_ring_cy, TANK_HEIGHT])
    rotate([0, 0, 180])
        translate([-turret_cx, -turret_cy, 0])
            turret_body();

// --- Gun barrel ---
// After 180° turret rotation, the trunnion at turret local [105, 47.5, 30]
// maps to global: turret_ring_center + rotate_180(local - center)
//   local offset from turret center: [105-60, 47.5-47.5, 30] = [45, 0, 30]
//   rotate 180°: [-45, 0, 30]
//   global: [225-45, 45+0, 80+30] = [180, 45, 110]
// Barrel built along +Z. After 180° turret rotation, "forward" is -X direction.
// rotate([0, 85, 0]) rotates +Z toward -X (toward tank front), 5° elevation
color("#3a4e1a")
translate([180, 45, 110])
    rotate([0, 85, 0])
        gun_barrel();

// --- Hull camera (ESP32-CAM at front) ---
color("DarkGreen", 0.8)
translate([3, HULL_WIDTH/2 - 13.5, TANK_HEIGHT * 0.5 + 5])
    esp32cam_dummy();

// --- Turret camera (inside turret, facing forward) ---
// After rotation, turret front camera is at global:
//   ring_center + rotate_180([15-60, 47.5-47.5, 25]) = [225+45, 45, 80+25] = [270, 45, 105]
// But camera should face forward, so place at the front of rotated turret
color("ForestGreen", 0.8)
translate([turret_ring_cx - 45, turret_ring_cy - 13.5, TANK_HEIGHT + 25])
    esp32cam_dummy();

// --- VL53L1X ToF (turret front, below camera) ---
color("Cyan", 0.8)
translate([turret_ring_cx - 35, turret_ring_cy - 9, TANK_HEIGHT + 15])
    vl53l1x_dummy();
