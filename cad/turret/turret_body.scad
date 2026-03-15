// M1A1 Abrams — Turret Body
// Fits within Bambu A1 Mini build volume (180x180x180mm)
// Integrated: turret ESP32-CAM, VL53L1X ToF sensor, slip-ring void, wire duct

use <../libs/common.scad>
use <../libs/m4_hardware.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

// --- Turret Parameters ---
turret_width = 95;
turret_length = 120;
turret_height = 50;
wall = 1.6;

// Turret ring (mates with hull)
ring_od = 92;                // Must match hull turret_ring_id
ring_height = 10;

// Gun mount
trunnion_width = 30;
trunnion_height = 20;
barrel_bore = 14;            // Bore for barrel bayonet mount

// ESP32-CAM gunner camera window
cam_window_width = 30;
cam_window_height = 25;

// VL53L1X ToF sensor window (co-axial with barrel)
tof_window_dia = 6;             // Aperture for laser

// Slip-ring void (wire pass-through from hull)
slip_ring_dia = 22;

// Wire duct (internal channel from slip-ring to electronics)
duct_width = 10;
duct_depth = 8;

$fn = 64;

// --- M1A1 Turret Profile ---
// Angular shape: wide cheek armor at front, narrower bustle at rear
// Flat top, sloped sides, wedge-shaped front armor
cheek_width = 15;           // Extra width from cheek armor blocks
cheek_length = 50;          // How far back cheek armor extends
bustle_length = 30;         // Rear bustle rack overhang
top_taper = 5;              // Top edges slope inward slightly

module turret_shell() {
    difference() {
        // Outer turret — angular M1A1 shape using polyhedron
        polyhedron(
            points = [
                // Bottom face (Z=0) — wide at front (cheek armor), narrow at rear
                [0, -cheek_width, 0],                          // 0: front-left-bottom (cheek)
                [cheek_length, -cheek_width, 0],               // 1: cheek-end-left-bottom
                [turret_length, 10, 0],                        // 2: rear-left-bottom (narrower)
                [turret_length + bustle_length, 15, 0],        // 3: bustle-left-bottom
                [turret_length + bustle_length, turret_width - 15, 0], // 4: bustle-right-bottom
                [turret_length, turret_width - 10, 0],         // 5: rear-right-bottom
                [cheek_length, turret_width + cheek_width, 0], // 6: cheek-end-right-bottom
                [0, turret_width + cheek_width, 0],            // 7: front-right-bottom (cheek)

                // Top face (Z=turret_height) — slightly tapered inward
                [0, -cheek_width + top_taper, turret_height],                    // 8
                [cheek_length, -cheek_width + top_taper, turret_height],         // 9
                [turret_length, 10 + top_taper, turret_height],                  // 10
                [turret_length + bustle_length, 15 + top_taper, turret_height],  // 11
                [turret_length + bustle_length, turret_width - 15 - top_taper, turret_height], // 12
                [turret_length, turret_width - 10 - top_taper, turret_height],   // 13
                [cheek_length, turret_width + cheek_width - top_taper, turret_height], // 14
                [0, turret_width + cheek_width - top_taper, turret_height],      // 15
            ],
            faces = [
                [7,6,5,4,3,2,1,0],         // bottom
                [8,9,10,11,12,13,14,15],    // top
                [0,1,9,8],                  // left cheek
                [1,2,10,9],                 // left side
                [2,3,11,10],                // left rear
                [3,4,12,11],                // rear
                [4,5,13,12],                // right rear
                [5,6,14,13],                // right side
                [6,7,15,14],                // right cheek
                [7,0,8,15],                 // front face
            ]
        );

        // Hollow interior
        translate([wall + 3, wall + 3, wall])
            cube([turret_length - 2*wall - 6, turret_width - 2*wall - 6, turret_height]);
    }
}

module turret_ring_bottom() {
    // Ring that sits inside the hull's turret ring
    translate([turret_length/2, turret_width/2, -ring_height])
    difference() {
        cylinder(h=ring_height, d=ring_od - PRINT_TOLERANCE*2);
        translate([0, 0, -0.05])
            cylinder(h=ring_height + 0.1, d=ring_od - 8);
    }
}

module gun_trunnion() {
    // Trunnion mount at FRONT of turret (same end as cheek armor)
    translate([15, turret_width/2, turret_height * 0.6])
    difference() {
        translate([-trunnion_width/2, -trunnion_width/2, 0])
            cube([trunnion_width, trunnion_width, trunnion_height]);
        // Barrel bore
        cylinder(h=trunnion_height + 0.1, d=barrel_bore);
        // Servo mounting holes
        for (dy = [-12, 12])
            translate([0, dy, trunnion_height/2])
                rotate([0, 90, 0])
                    m4_hole(depth=trunnion_width);
    }
}

module camera_window() {
    // Camera window at FRONT face of turret (X=0 face, where cheek armor is)
    translate([-0.1, turret_width/2 - cam_window_width/2, turret_height * 0.4])
        cube([wall + 0.2, cam_window_width, cam_window_height]);
}

module tof_window() {
    // VL53L1X laser aperture at front face, below camera
    translate([-0.1, turret_width/2, turret_height * 0.35])
        rotate([0, 90, 0])
            cylinder(h=wall + 0.2, d=tof_window_dia);
}

module turret_cam_mount() {
    // ESP32-CAM mount inside turret, behind front camera window
    translate([10, turret_width/2 - 13.5, turret_height * 0.4 + 2])
        esp32cam_mount(standoff_h=3);
}

module turret_tof_mount() {
    // VL53L1X ToF sensor mount, near front, below camera
    translate([15, turret_width/2 - 9, turret_height * 0.25])
        vl53l1x_mount(standoff_h=3);
}

module turret_slip_ring_void() {
    // Wire pass-through at bottom center of turret ring
    translate([turret_length/2, turret_width/2, -ring_height - 0.05])
        cylinder(h=ring_height + wall + 0.1, d=slip_ring_dia);
}

module turret_wire_duct() {
    // Internal wire channel from slip-ring void to camera/sensor area
    translate([turret_length/2, turret_width/2 - duct_width/2, wall])
        cube([turret_length/2 - 15, duct_width, duct_depth]);
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
    translate([0, 0, 0]) {
        rib_t = 1.2;
        translate([turret_length/2, turret_width/2 - duct_width/2 - rib_t, wall])
            cube([turret_length/2 - 15, rib_t, duct_depth]);
        translate([turret_length/2, turret_width/2 + duct_width/2, wall])
            cube([turret_length/2 - 15, rib_t, duct_depth]);
    }
}

turret_body();
