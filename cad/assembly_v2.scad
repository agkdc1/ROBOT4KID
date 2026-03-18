// M1A1 Abrams 1/18 Scale — Full Assembly with ALL components visible
// Hull + Turret + Tracks (1:18) + Electronics + Firing System
//
// Hull: 440 x 203 x 61 mm (X=length, Y=width, Z=height)
// Turret: 181(W) x 306(L) x 52(H) mm — rotated -90° so length aligns with hull X
// Tracks: 1:18 scale, 400mm side plates, 7 road wheels per side

use <chassis/hull_v2.scad>
use <turret/turret_v2.scad>
use <chassis/track_assembly_v2.scad>
use <chassis/modular_inserts.scad>
use <libs/hardware_v2.scad>

// --- Hull Constants (match hull_v2.scad) ---
hull_len   = 440;
hull_w     = 203;
hull_h     = 61;
front_len  = 147;
center_len = 146;

// --- Turret Constants (match turret_v2.scad) ---
tw = 181;   // turret_width  (X in turret space)
tl = 306;   // turret_length (Y in turret space)

// --- Hull at origin ---
hull_assembly();

// --- Turret on hull ---
// Turret ring center must land at hull center section ring:
//   hull X = front_len + center_len/2 = 147 + 73 = 220
//   hull Y = hull_w/2 = 101.5
// Turret ring is at (tw/2, tl/2) = (90.5, 153) in turret space.
// After rotate -90°: ring maps to (153, -90.5) in rotated space.
// Translate so (153, -90.5) + offset = (220, 101.5):
//   offset = (220 - 153, 101.5 + 90.5) = (67, 192)
translate([67, 192, hull_h + 0.2])   // hull top + assembly gap
    rotate([0, 0, -90])              // align turret length with hull X
        turret_assembly();

// --- Track Assemblies (1:18 scale) ---
// track_assembly_v2.scad: SIDE_PLATE_LENGTH=400, SIDE_PLATE_WIDTH=35
// Center tracks along hull length: offset = (440-400)/2 = 20mm
track_plate_w = 35;  // from track_assembly_v2.scad
track_offset_x = 20; // center 400mm tracks on 440mm hull

color("#4a4a3a") {
    // Left side tracks
    translate([track_offset_x, -track_plate_w, 0])
        track_assembly_v2_left();

    // Right side tracks
    translate([track_offset_x, hull_w + track_plate_w, 0])
        mirror([0, 1, 0])
            track_assembly_v2_left();
}

// --- Modular Inserts (inside hull center section) ---
translate([front_len, 0, 0]) {
    // Power hub insert (center of hull center)
    translate([15, 70, 2])
        power_hub_insert();
    translate([15, 70, 2])
        power_hub_ghosts();

    // Sensor insert (center)
    translate([55, 85, 2])
        sensor_insert();
}

// Drivetrain inserts (inside hull front, one per side)
translate([10, 10, 2])
    drivetrain_insert();
translate([10, 10, 2])
    drivetrain_ghosts();
translate([10, hull_w - 45, 2])
    drivetrain_insert();
translate([10, hull_w - 45, 2])
    drivetrain_ghosts();

// --- Visible M4 screws at hull seams ---
// Front-center seam (4 bolts)
for (i = [0:3]) {
    by = 12 + i * ((hull_w - 24) / 3);
    // M4 bolt head visible on front section side
    translate([front_len, by, hull_h/2])
        rotate([0, 90, 0])
            m4_screw(12);
}

// Center-rear seam (4 bolts)
for (i = [0:3]) {
    by = 12 + i * ((hull_w - 24) / 3);
    translate([front_len + center_len, by, hull_h/2])
        rotate([0, 90, 0])
            m4_screw(12);
}

// --- Ground plane ---
color("#4a4a3a", 0.3)
translate([-40, -60, -1])
    cube([540, 340, 0.5]);
