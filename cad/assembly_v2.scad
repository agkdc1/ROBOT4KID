// M1A1 Abrams 1/18 Scale — Full Assembly with ALL components visible
// Hull + Turret + Electronics + Firing System

use <chassis/hull_v2.scad>
use <turret/turret_v2.scad>

// Hull at origin
hull_assembly();

// Turret on top of hull (center section turret ring)
// Hull center starts at X=147, turret ring at center of that section
// Turret ring center: X = 147 + 146/2 = 220, Y = 203/2 = 101.5
// Turret length = 306, split front=153, rear=153
// Turret ring in turret is at ~50% length = 153
translate([220, 101.5, 61 + 0.2])  // hull_height + gap
    translate([-153, -181/2, 0])    // offset turret so ring aligns
        turret_assembly();

// Ground plane
color("#4a4a3a", 0.3)
translate([-20, -20, -1])
    cube([480, 250, 0.5]);
