// M1A1 Abrams — Hull Chassis
// Split into front and rear halves for Bambu A1 Mini build volume

use <../libs/common.scad>
use <../libs/m4_hardware.scad>

// --- Hull Parameters ---
hull_length = 150;          // Per half (total 300mm)
hull_width = 90;            // Between tracks
hull_height = 80;
wall = 1.6;                 // Structural walls

// Glacis plate angle
glacis_angle = 30;          // Front slope angle

// Turret ring
turret_ring_od = 100;       // Outer diameter
turret_ring_id = 92;        // Inner diameter (bearing surface)
turret_ring_height = 8;

// Battery compartment
battery_length = 70;
battery_width = 40;
battery_height = 30;

// Motor mount dimensions
motor_mount_width = 30;
motor_mount_depth = 40;
motor_mount_height = 25;

// Part selector — set via CLI: -D 'part="front"'
part = "assembly";  // "front" | "rear" | "assembly"

module hull_base(length) {
    difference() {
        // Outer shell
        rounded_cube([length, hull_width, hull_height], r=3);

        // Hollow interior
        translate([wall, wall, wall])
            cube([length - 2*wall, hull_width - 2*wall, hull_height]);
    }
}

module glacis_plate() {
    // Angled front plate (M1A1 style)
    translate([0, 0, hull_height * 0.6])
    rotate([0, -glacis_angle, 0])
        cube([hull_height * 0.5, hull_width, wall]);
}

module turret_ring() {
    difference() {
        cylinder(h=turret_ring_height, d=turret_ring_od);
        translate([0, 0, -0.05])
            cylinder(h=turret_ring_height + 0.1, d=turret_ring_id);
    }
}

module battery_compartment() {
    difference() {
        cube([battery_length + 2*wall, battery_width + 2*wall, battery_height + wall]);
        translate([wall, wall, wall])
            cube([battery_length, battery_width, battery_height + 0.1]);
    }
}

module motor_mount() {
    difference() {
        cube([motor_mount_depth, motor_mount_width, motor_mount_height]);
        // Motor shaft hole
        translate([motor_mount_depth/2, motor_mount_width/2, -0.1])
            cylinder(h=motor_mount_height + 0.2, d=6);
        // Mounting holes
        for (dx = [-10, 10])
            for (dy = [-8, 8])
                translate([motor_mount_depth/2 + dx, motor_mount_width/2 + dy, -0.1])
                    m4_hole(depth=motor_mount_height + 0.2);
    }
}

module hull_front() {
    difference() {
        hull_base(hull_length);

        // ESP32-CAM front window
        translate([wall - 0.1, hull_width/2 - 15, hull_height * 0.5])
            cube([wall + 0.2, 30, 25]);
    }

    // Motor mounts (front pair)
    for (side = [0, 1])
        translate([20, side * (hull_width - motor_mount_width), 0])
            motor_mount();

    // Split joint — alignment keys
    translate([hull_length, hull_width/4, hull_height/3])
        split_key();
    translate([hull_length, hull_width*3/4, hull_height/3])
        split_key();

    // Split joint — M4 bolt holes
    translate([hull_length - 5, hull_width/4, hull_height*2/3])
        rotate([0, 90, 0]) m4_hole(depth=10);
    translate([hull_length - 5, hull_width*3/4, hull_height*2/3])
        rotate([0, 90, 0]) m4_hole(depth=10);
}

module hull_rear() {
    difference() {
        hull_base(hull_length);

        // Split joint — alignment sockets
        translate([0, hull_width/4, hull_height/3])
            split_socket();
        translate([0, hull_width*3/4, hull_height/3])
            split_socket();

        // Split joint — M4 bolt holes
        translate([-5, hull_width/4, hull_height*2/3])
            rotate([0, 90, 0]) m4_hole(depth=10);
        translate([-5, hull_width*3/4, hull_height*2/3])
            rotate([0, 90, 0]) m4_hole(depth=10);
    }

    // Turret ring (centered on rear half)
    translate([hull_length/2, hull_width/2, hull_height])
        turret_ring();

    // Battery compartment
    translate([hull_length/2 - battery_length/2, hull_width/2 - battery_width/2 - wall, wall])
        battery_compartment();
}

module hull_assembly() {
    hull_front();
    translate([hull_length, 0, 0])
        hull_rear();
}

// Render selected part
if (part == "front") hull_front();
else if (part == "rear") hull_rear();
else if (part == "assembly") hull_assembly();
