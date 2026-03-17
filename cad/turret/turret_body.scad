// M1A1 Abrams — Turret Body (1:26 scale, Gemini proportional analysis)
// Fits within Bambu A1 Mini build volume (180x180x180mm)
// Integrated: turret ESP32-CAM, VL53L1X ToF sensor, slip-ring void, wire duct
//
// Shape: "pentagram" top-view — sloped faceted nose, flat sides,
// pronounced composite cheek armor blocks, very low flat profile,
// bustle rack at rear.

use <../libs/common.scad>
use <../libs/m4_hardware.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

// --- Turret Parameters (1:26 scale from Gemini) ---
turret_length = 175;              // Main body length (was 150, Gemini ratio fix)
turret_width  = 123;              // Main body width (was 95)
turret_height = 30;               // Very low profile (was 50)
wall = 1.6;                       // Min wall thickness

// Turret ring (mates with hull turret_ring_id = 74)
ring_od = 74;                     // Must match hull turret_ring_id
ring_height = 10;

// Gun mount
trunnion_width = 30;
trunnion_height = 16;             // Shorter — turret is only 30mm tall
barrel_bore = 14;                 // Bore for barrel bayonet mount

// ESP32-CAM gunner camera window
cam_window_width = 30;
cam_window_height = 14;           // Shorter to fit 30mm turret

// VL53L1X ToF sensor window (co-axial with barrel)
tof_window_dia = 6;               // Aperture for laser

// Slip-ring void (wire pass-through from hull)
slip_ring_dia = 22;

// Wire duct (internal channel from slip-ring to electronics)
duct_width = 10;
duct_depth = 6;                   // Shallower for low turret

$fn = 64;

// --- M1A1 Turret Profile ---
// Pentagram top-view: wide cheek armor at front, flat sides, narrow bustle at rear
// Sloped/faceted nose face (not vertical)
cheek_width  = 20;                // Prominent composite armor blocks (was 15)
cheek_length = 70;                // Cheek armor extends further back (was 50)
bustle_length = 0;                // Bustle integrated into main body (was 25)
nose_slope   = 15;                // Nose face angled back this far (sloped, not vertical)
top_taper    = 3;                 // Top edges slope inward slightly

// Derived: turret_length = 175mm fits 180mm build volume
// Ratio: 175/300 = 0.58 (closer to Gemini target 0.69 than old 0.50)

// Half-width for symmetric construction
half_w = turret_width / 2;

// --- Turret Shell ---
// Polyhedron built around Y-centerline (Y=0 = turret center)
// X=0 is front tip of nose, X grows toward rear
// Y centered: left = -half_w, right = +half_w

module turret_shell() {
    // Build turret from hull() operations for reliable manifold mesh
    // Pentagram top-view: wide cheeks, narrow nose, bustle at rear
    full_cheek_w = half_w + cheek_width;  // Total half-width at cheek

    difference() {
        union() {
            // Main turret body: hull from front nose to rear
            hull() {
                // Front nose (narrow, angled)
                translate([nose_slope, 0, 0])
                    cube([1, half_w * 0.9, turret_height], center=true);
                // Cheek armor zone (widest point)
                translate([cheek_length/2, 0, 0])
                    cube([cheek_length, full_cheek_w * 2, turret_height], center=true);
            }
            // Cheek to rear body
            hull() {
                translate([cheek_length/2, 0, 0])
                    cube([cheek_length, full_cheek_w * 2, turret_height], center=true);
                translate([turret_length * 0.85, 0, 0])
                    cube([1, (half_w + 5) * 2, turret_height], center=true);
            }
            // Rear taper with integrated bustle rack
            hull() {
                translate([turret_length * 0.80, 0, 0])
                    cube([1, (half_w + 5) * 2, turret_height], center=true);
                translate([turret_length * 0.92, 0, 0])
                    cube([1, half_w * 1.1, turret_height], center=true);
            }
            // Bustle rack (integrated into main body)
            hull() {
                translate([turret_length * 0.92, 0, 0])
                    cube([1, half_w * 1.1, turret_height], center=true);
                translate([turret_length, 0, 0])
                    cube([1, half_w * 0.85, turret_height * 0.85], center=true);
            }
        }

        // Hollow interior
        translate([nose_slope + wall + 3, 0, turret_height/2 + wall])
            cube([
                turret_length - nose_slope - 2*wall - 6,
                full_cheek_w * 2 - 2*wall - 8,
                turret_height
            ], center=true);
    }
}

module turret_ring_bottom() {
    // Ring that sits inside the hull's turret ring
    // Centered on turret body at roughly turret midpoint
    ring_x = turret_length * 0.42;   // Slightly forward of center (turret CG)
    translate([ring_x, 0, -ring_height])
    difference() {
        cylinder(h = ring_height, d = ring_od - PRINT_TOLERANCE * 2);
        translate([0, 0, -0.05])
            cylinder(h = ring_height + 0.1, d = ring_od - 8);
    }
}

module gun_trunnion() {
    // Trunnion mount at FRONT of turret (same end as cheek armor)
    // X=15 — gun faces forward (negative X direction = front)
    translate([15, 0, turret_height * 0.5])
    difference() {
        translate([-trunnion_width/2, -trunnion_width/2, 0])
            cube([trunnion_width, trunnion_width, trunnion_height]);
        // Barrel bore — horizontal, pointing forward
        rotate([0, -90, 0])
            cylinder(h = trunnion_width, d = barrel_bore);
        // Servo mounting holes (M4) on sides
        for (dy = [-12, 12])
            translate([0, dy, trunnion_height / 2])
                rotate([0, 90, 0])
                    m4_hole(depth = trunnion_width);
    }
}

module camera_window() {
    // Camera window at FRONT face of turret
    // Cut into the nose slope area — penetrates the angled front
    translate([0, -cam_window_width / 2, turret_height * 0.3])
        cube([nose_slope + wall + 0.2, cam_window_width, cam_window_height]);
}

module tof_window() {
    // VL53L1X laser aperture at front face, below camera
    translate([0, 0, turret_height * 0.2])
        rotate([0, 90, 0])
            cylinder(h = nose_slope + wall + 0.2, d = tof_window_dia);
}

module turret_cam_mount() {
    // ESP32-CAM mount inside turret, behind front camera window
    // Camera lens faces forward (toward X=0)
    translate([nose_slope + 5, -13.5, turret_height * 0.3 + 1])
        esp32cam_mount(standoff_h = 2);
}

module turret_tof_mount() {
    // VL53L1X ToF sensor mount, near front, below camera
    translate([nose_slope + 5, -9, turret_height * 0.1])
        vl53l1x_mount(standoff_h = 2);
}

module turret_slip_ring_void() {
    // Wire pass-through at bottom center of turret ring
    ring_x = turret_length * 0.42;
    translate([ring_x, 0, -ring_height - 0.05])
        cylinder(h = ring_height + wall + 0.1, d = slip_ring_dia);
}

module turret_wire_duct() {
    // Internal wire channel from slip-ring void to camera/sensor area at front
    ring_x = turret_length * 0.42;
    translate([nose_slope + 20, -duct_width / 2, wall])
        cube([ring_x - nose_slope - 20, duct_width, duct_depth]);
}

module turret_body() {
    difference() {
        union() {
            turret_shell();
            turret_ring_bottom();
            gun_trunnion();
            turret_cam_mount();
            turret_tof_mount();
        }
        camera_window();
        tof_window();
        turret_slip_ring_void();
    }

    // Wire duct as raised channel walls (additive)
    rib_t = 1.2;
    ring_x = turret_length * 0.42;
    duct_start = nose_slope + 20;
    duct_len = ring_x - duct_start;

    translate([duct_start, -duct_width / 2 - rib_t, wall])
        cube([duct_len, rib_t, duct_depth]);
    translate([duct_start, duct_width / 2, wall])
        cube([duct_len, rib_t, duct_depth]);
}

turret_body();
