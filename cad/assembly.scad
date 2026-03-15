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

// --- Assembly Positions ---

// Hull (at origin)
color("#5a6e3a")  // Olive drab
hull_assembly();

// Track assemblies (both sides)
color("#4a4a3a")  // Dark olive
// Left track
translate([0, -TRACK_WIDTH, 0])
    track_assembly_left();
// Right track (mirrored)
translate([0, HULL_WIDTH + TRACK_WIDTH, 0])
    mirror([0, 1, 0])
        track_assembly_left();

// Electronics bay (inside rear hull)
color("#2a3a2a", 0.6)  // Dark green, semi-transparent
translate([150 + (150 - 138)/2, (90 - 86)/2, 1.6])  // Rear hull, on floor
    assembly();  // from electronics_bay.scad — shows tray + dummy components

// Turret (on top of hull)
color("#4a5e2a")
translate([225, 45, 80])  // Centered on rear hull turret ring
    turret_body();

// Barrel (on turret) — barrel module builds along Z, rotate to point forward (X)
color("#3a4e1a")
translate([225 + 60, 45 + 47.5, 80 + 30])  // Trunnion position on turret
    rotate([0, -85, 0])     // -90° to horizontal + 5° elevation
        gun_barrel();

// Hull camera (ESP32-CAM at front — shown as dummy)
color("DarkGreen", 0.8)
translate([3, 90/2 - 13.5, 80 * 0.5 + 5])
    esp32cam_dummy();

// Turret camera (ESP32-CAM inside turret — shown as dummy)
color("ForestGreen", 0.8)
translate([225 + 120 - 45, 45 + 95/2 - 13.5, 80 + 50 * 0.4 + 5])
    esp32cam_dummy();

// VL53L1X ToF (inside turret, below camera)
color("Cyan", 0.8)
translate([225 + 120 - 25, 45 + 95/2 - 9, 80 + 50 * 0.25 + 3])
    vl53l1x_dummy();
