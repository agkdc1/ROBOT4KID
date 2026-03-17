// M1A1 Abrams — Full Assembly Visualization
// Use this file to preview the complete tank with all components
// Proportions from Gemini analysis at 1:26 scale
// Hull: 300x139x55, Turret: 175x123x30, Barrel: 180mm, 7 road wheels

include <libs/common.scad>     // include (not use) to get variables
use <libs/electronics.scad>
use <chassis/hull.scad>
use <chassis/track_assembly.scad>
use <chassis/electronics_bay.scad>
use <turret/turret_body.scad>
use <turret/gun_barrel.scad>

// --- Assembly Parameters ---
hull_length = 150;          // Per half
hull_width = 139;           // HULL_WIDTH
hull_height = 55;           // TANK_HEIGHT
track_width = 24;           // TRACK_WIDTH

// Turret dimensions (from turret_body.scad)
turret_length = 175;        // Was 150, Gemini ratio fix (175/300 = 0.58)
turret_width = 123;
turret_height = 30;

// Hull turret ring center: X = 150+75 = 225, Y = hull_width/2
turret_ring_cx = hull_length + hull_length/2;   // 225
turret_ring_cy = hull_width / 2;                // 69.5

// Turret is Y-centered (Y=0 is centerline), ring at 42% of length
turret_ring_local_x = turret_length * 0.42;     // ~63

// --- Hull (at origin) ---
color("#5a6e3a")
hull_assembly();

// --- Tracks (both sides, 2 per side to cover full 300mm hull) ---
// Ground contact: road wheel centers are at ROAD_WHEEL_Z = DIA/2 + 2,
// so wheel bottoms sit 2mm above side plate bottom. Shift tracks down
// by 2mm so road wheels touch Z=0 (ground plane).
track_ground_drop = 0;  // Track belt bottom is at Z=0 in local coords, no offset needed
color("#4a4a3a") {
    // Left side — front track
    translate([0, -track_width, -track_ground_drop])
        track_assembly_left();
    // Left side — rear track
    translate([hull_length, -track_width, -track_ground_drop])
        track_assembly_left();
    // Right side — front track
    translate([0, hull_width + track_width, -track_ground_drop])
        mirror([0, 1, 0]) track_assembly_left();
    // Right side — rear track
    translate([hull_length, hull_width + track_width, -track_ground_drop])
        mirror([0, 1, 0]) track_assembly_left();
}

// --- Electronics bay (inside rear hull) ---
color("#2a3a2a", 0.6)
translate([hull_length + (hull_length - 138)/2, (hull_width - 133)/2, 1.6])
    assembly();

// --- Turret (on top of hull) ---
// Turret is Y-centered: Y ranges from -turret_width/2 to +turret_width/2
// Position: turret ring X aligns, turret centerline aligns with hull centerline
// Clearance: 0.2mm gap between turret bottom and hull top (printability)
// Turret ring: ring_od - 2*PRINT_TOLERANCE = 73.6mm into 74mm hull ring → 0.2mm/side radial clearance
turret_hull_gap = 0.2;  // mm — assembly clearance at turret-hull interface
color("#4a5e2a")
translate([turret_ring_cx - turret_ring_local_x,
           turret_ring_cy,
           hull_height + turret_hull_gap])
    turret_body();

// --- Gun barrel ---
// Trunnion at turret local [15, 0, turret_height*0.6] (Y-centered turret)
// Global X = turret_global_x + 15
// Global Y = turret_ring_cy (centerline)
// Global Z = hull_height + gap + turret_height*0.6
// Barrel-mantlet clearance: bayonet OD 13.5mm into 14mm bore → 0.25mm/side radial gap (built into turret_body)
barrel_trunnion_x = turret_ring_cx - turret_ring_local_x + 15;
barrel_trunnion_y = turret_ring_cy;
barrel_trunnion_z = hull_height + turret_hull_gap + turret_height * 0.6;
color("#3a4e1a")
translate([barrel_trunnion_x, barrel_trunnion_y, barrel_trunnion_z])
    rotate([0, -85, 0])    // Z->-X with 5° elevation
        gun_barrel();

// --- Hull camera (ESP32-CAM at front) ---
color("DarkGreen", 0.8)
translate([3, hull_width/2 - 13.5, hull_height * 0.4 + 5])
    esp32cam_dummy();

// --- Turret camera (inside turret front) ---
turret_global_x = turret_ring_cx - turret_ring_local_x;
color("ForestGreen", 0.8)
translate([turret_global_x + 10, turret_ring_cy - 13.5, hull_height + turret_hull_gap + turret_height * 0.4 + 2])
    esp32cam_dummy();

// --- VL53L1X ToF (turret front, below camera) ---
color("Cyan", 0.8)
translate([turret_global_x + 15, turret_ring_cy, hull_height + turret_hull_gap + turret_height * 0.35])
    vl53l1x_dummy();

// --- Ground Plane (visual reference for ground contact verification) ---
// Track belt bottom is at Z=-1 (belt_z = rw_bottom - TRACK_BELT_THICK = 2-3 = -1)
// Ground plane sits flush with track belt bottom
color("#3a3a2a", 0.4)
translate([-50, -50, -1.5])
    cube([400, 300, 0.5]);
