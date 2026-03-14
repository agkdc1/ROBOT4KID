// M1A1 Abrams — Full Assembly Visualization
// Use this file to preview the complete tank assembly

use <libs/common.scad>
use <chassis/hull.scad>
use <turret/turret_body.scad>
use <turret/gun_barrel.scad>

// --- Assembly Positions ---

// Hull (at origin)
color("#5a6e3a")  // Olive drab
hull_assembly();

// Turret (on top of hull)
color("#4a5e2a")
translate([225, 45, 80])  // Centered on rear hull turret ring
    turret_body();

// Barrel (on turret)
color("#3a4e1a")
translate([340, 92, 110])  // At trunnion
    rotate([0, -5, 0])     // Slight elevation
        gun_barrel();
