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
track_x_offset = (TANK_LENGTH - 150) / 2;  // Center 150mm tracks along 300mm hull

// Hull (at origin)
color("#5a6e3a")
hull_assembly();

// Track assemblies (both sides, centered along hull)
color("#4a4a3a")
translate([track_x_offset, -TRACK_WIDTH, 0])
    track_assembly_left();
color("#4a4a3a")
translate([track_x_offset, HULL_WIDTH + TRACK_WIDTH, 0])
    mirror([0, 1, 0])
        track_assembly_left();

// Electronics bay (inside rear hull)
color("#2a3a2a", 0.6)  // Dark green, semi-transparent
translate([150 + (150 - 138)/2, (90 - 86)/2, 1.6])  // Rear hull, on floor
    assembly();  // from electronics_bay.scad — shows tray + dummy components

// Turret (on top of hull, centered over turret ring)
// Hull turret ring center is at: X=225 (150+75), Y=45 (90/2), Z=80 (hull height)
// Turret ring_bottom extends 10mm below turret, so turret base sits at Z=80
// Turret center: turret_length/2=60, turret_width/2=47.5
// Place turret so its center aligns with hull turret ring center
color("#4a5e2a")
translate([225 - 60, 45 - 47.5, 80])
    turret_body();

// Barrel — gun_trunnion is at turret local [105, 47.5, 30]
// Global trunnion = turret_translate + [105, 47.5, 30]
//                 = [225-60+105, 45-47.5+47.5, 80+30] = [270, 45, 110]
// Barrel module extends along +Z from origin. rotate to point toward -X (front of tank)
// rotate([0, -90, 0]) = horizontal pointing -X; add 5° elevation = -85°
color("#3a4e1a")
translate([270, 45, 110])
    rotate([0, -85, 0])
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
