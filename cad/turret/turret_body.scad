// M1A1 Abrams — Turret Body
// Fits within Bambu A1 Mini build volume (180x180x180mm)

use <../libs/common.scad>
use <../libs/m4_hardware.scad>

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

$fn = 64;

module turret_shell() {
    difference() {
        // Outer shape — elongated with flat top (M1A1 style)
        hull() {
            translate([10, 10, 0])
                cylinder(h=turret_height, r=10);
            translate([turret_length-10, 10, 0])
                cylinder(h=turret_height, r=10);
            translate([10, turret_width-10, 0])
                cylinder(h=turret_height, r=10);
            translate([turret_length-10, turret_width-10, 0])
                cylinder(h=turret_height, r=10);
        }

        // Hollow interior
        translate([wall, wall, wall])
        hull() {
            translate([10, 10, 0])
                cylinder(h=turret_height, r=10-wall);
            translate([turret_length-10-wall, 10, 0])
                cylinder(h=turret_height, r=10-wall);
            translate([10, turret_width-10-wall, 0])
                cylinder(h=turret_height, r=10-wall);
            translate([turret_length-10-wall, turret_width-10-wall, 0])
                cylinder(h=turret_height, r=10-wall);
        }
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
    // Trunnion mount for barrel elevation
    translate([turret_length - 15, turret_width/2, turret_height * 0.6])
    difference() {
        // Trunnion block
        translate([-trunnion_width/2, -trunnion_width/2, 0])
            cube([trunnion_width, trunnion_width, trunnion_height]);

        // Barrel bore (bayonet mount)
        rotate([0, 0, 0])
            cylinder(h=trunnion_height + 0.1, d=barrel_bore);

        // Servo mounting holes
        for (dy = [-12, 12])
            translate([0, dy, trunnion_height/2])
                rotate([0, 90, 0])
                    m4_hole(depth=trunnion_width);
    }
}

module camera_window() {
    // Front camera window for gunner ESP32-CAM
    translate([turret_length - wall - 0.1, turret_width/2 - cam_window_width/2, turret_height * 0.4])
        cube([wall + 0.2, cam_window_width, cam_window_height]);
}

module turret_body() {
    difference() {
        union() {
            turret_shell();
            turret_ring_bottom();
            gun_trunnion();
        }
        camera_window();
    }
}

turret_body();
