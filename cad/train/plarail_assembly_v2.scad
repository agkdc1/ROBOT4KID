// Plarail Smart FPV Train — Full Assembly Visualization
// Train on a straight track section with tunnel portal
// All dimensions in mm

use <plarail_chassis_v2.scad>
use <plarail_shell_v2.scad>
use <plarail_track.scad>

// --- Train Assembly (chassis + shell) ---
// Shell sits on top of chassis at split line
module train_assembly() {
    // Chassis
    chassis_assembly();

    // Shell on top
    translate([0, 0, 0])
        shell_assembly();
}

// --- Scene Layout ---
// Train sitting on a straight track, tunnel portal at one end

// Track (straight section, centered under train)
color("#8B7355")
translate([-40, -25 + 33/2, -3])  // position track under train
    straight_track(215);

// Train on track
translate([0, 0, 5])  // raise train above track surface (wheel + rail height)
    train_assembly();

// Tunnel portal at far end
color("#8B4513")
translate([180, -25 + 33/2, -3])
    tunnel_portal();

// Ground plane
color("#4a6a3a", 0.3)
translate([-60, -40, -4])
    cube([320, 120, 0.5]);
