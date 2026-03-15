// M1A1 Abrams — Hull Chassis
// Split into front and rear halves for Bambu A1 Mini build volume
// Integrated: hull camera mount, slip-ring void, electronics bay mounting

use <../libs/common.scad>
use <../libs/m4_hardware.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

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

// Slip-ring void
slip_ring_dia = 22;             // For wire pass-through to turret

// Hull camera (ESP32-CAM)
hull_cam_width = 30;            // Window width
hull_cam_height = 25;           // Window height

// Electronics bay mounting (4x M3 in rear hull floor)
ebay_mount_inset = 6;
ebay_mount_x = 138;             // Electronics bay length
ebay_mount_y = 86;              // Electronics bay width

// Part selector — set via CLI: -D 'part="front"'
part = "assembly";  // "front" | "rear" | "assembly"

// --- M1A1 Hull Profile ---
// Lower hull: vertical sides, flat bottom
// Upper hull: sloped sides (inward taper), flat deck with turret ring cutout
// Front: steep glacis plate at 30°
// Rear: vertical engine deck with exhaust grilles

upper_taper = 8;           // How much the upper hull sides slope inward (mm)
deck_height = hull_height * 0.6;  // Where the upper hull starts tapering
side_skirt_drop = 10;      // Side skirts extend below hull bottom
rear_slope = 15;           // Rear deck slope angle

module hull_profile_2d() {
    // Cross-section of the hull (in YZ plane)
    // Lower hull: straight sides
    // Upper hull: tapered inward
    polygon([
        [0, 0],                                         // bottom-left
        [hull_width, 0],                                // bottom-right
        [hull_width, deck_height],                      // right at deck line
        [hull_width - upper_taper, hull_height],        // right top (tapered in)
        [upper_taper, hull_height],                     // left top (tapered in)
        [0, deck_height],                               // left at deck line
    ]);
}

module hull_base(length) {
    difference() {
        union() {
            // Main hull body with tapered upper sides
            linear_extrude(height=length)
                hull_profile_2d();

            // Side skirts (thin plates extending below hull)
            for (side = [0, hull_width - wall])
                translate([side, -side_skirt_drop, 0])
                    cube([wall, side_skirt_drop, length]);
        }

        // Hollow interior
        translate([wall, wall, wall])
            linear_extrude(height=length - 2*wall)
                offset(r=-wall)
                    hull_profile_2d();
    }
}

module hull_base_oriented(length) {
    // Rotate so hull extends along X (length), Y (width), Z (height)
    // hull_base extrudes along Z, so rotate to align
    rotate([90, 0, 90])
        hull_base(length);
    // After rotation: extrusion axis (Z) becomes X
    // hull_profile_2d Y becomes Z (height), polygon X becomes Y (width)
    // Need to fix translation — the rotation moves origin
    // Actually let's just do it properly:
}

// Simpler approach: build the hull directly in XYZ
module hull_shape(length) {
    difference() {
        // Outer hull with sloped upper armor
        polyhedron(
            points = [
                // Bottom face (Z=0)
                [0, 0, 0],                                    // 0: front-left-bottom
                [length, 0, 0],                               // 1: rear-left-bottom
                [length, hull_width, 0],                      // 2: rear-right-bottom
                [0, hull_width, 0],                           // 3: front-right-bottom
                // Deck line (Z=deck_height)
                [0, 0, deck_height],                          // 4: front-left-deck
                [length, 0, deck_height],                     // 5: rear-left-deck
                [length, hull_width, deck_height],             // 6: rear-right-deck
                [0, hull_width, deck_height],                  // 7: front-right-deck
                // Top face (Z=hull_height, tapered inward)
                [0, upper_taper, hull_height],                 // 8: front-left-top
                [length, upper_taper, hull_height],            // 9: rear-left-top
                [length, hull_width-upper_taper, hull_height], // 10: rear-right-top
                [0, hull_width-upper_taper, hull_height],      // 11: front-right-top
            ],
            faces = [
                [3,2,1,0],     // bottom
                [8,9,10,11],   // top
                [0,1,5,4],     // left lower
                [4,5,9,8],     // left upper (sloped)
                [2,3,7,6],     // right lower
                [6,7,11,10],   // right upper (sloped)
                [0,4,8,11,7,3],// front
                [1,2,6,10,9,5],// rear
            ]
        );

        // Hollow interior (offset inward by wall thickness)
        translate([wall, wall, wall])
            cube([length - 2*wall, hull_width - 2*wall, hull_height]);
    }

    // Side skirts
    for (y_pos = [-2, hull_width])
        translate([0, y_pos, -side_skirt_drop])
            cube([length, 2, deck_height + side_skirt_drop]);
}

module glacis_plate() {
    // Steep front glacis plate (M1A1 has ~82° from horizontal = very steep)
    // Creates a sloped wedge at the front of the hull
    hull() {
        translate([0, wall, deck_height])
            cube([wall, hull_width - 2*wall, hull_height - deck_height]);
        translate([-hull_height * sin(glacis_angle), wall, hull_height * 0.3])
            cube([wall, hull_width - 2*wall, wall]);
    }
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

module hull_cam_mount() {
    // ESP32-CAM cradle at front of hull (driver camera, fixed position)
    // Recessed behind the armor window
    translate([wall + 2, hull_width/2 - 13.5, hull_height * 0.5 + 2])
        esp32cam_mount(standoff_h=3);
}

module hull_front() {
    difference() {
        union() {
            hull_shape(hull_length);
            glacis_plate();
            hull_cam_mount();
        }

        // ESP32-CAM front window (lens aperture)
        translate([-0.1, hull_width/2 - hull_cam_width/2, hull_height * 0.5])
            cube([wall + 5, hull_cam_width, hull_cam_height]);
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

module ebay_floor_mounts() {
    // M3 threaded holes in hull floor for electronics bay mounting
    ebay_ox = (hull_length - ebay_mount_x) / 2;
    ebay_oy = (hull_width - ebay_mount_y) / 2;
    positions = [
        [ebay_ox + ebay_mount_inset,                  ebay_oy + ebay_mount_inset],
        [ebay_ox + ebay_mount_x - ebay_mount_inset,   ebay_oy + ebay_mount_inset],
        [ebay_ox + ebay_mount_inset,                  ebay_oy + ebay_mount_y - ebay_mount_inset],
        [ebay_ox + ebay_mount_x - ebay_mount_inset,   ebay_oy + ebay_mount_y - ebay_mount_inset]
    ];
    for (p = positions)
        translate([p[0], p[1], -0.05])
            m3_hole(depth=wall + 0.1);
}

module hull_rear() {
    difference() {
        hull_shape(hull_length);

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

        // Slip-ring void at turret ring center
        translate([hull_length/2, hull_width/2, hull_height - 0.05])
            cylinder(h=turret_ring_height + 0.2, d=slip_ring_dia);

        // Electronics bay mounting holes in floor
        ebay_floor_mounts();
    }

    // Turret ring (centered on rear half)
    translate([hull_length/2, hull_width/2, hull_height])
        turret_ring();
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
