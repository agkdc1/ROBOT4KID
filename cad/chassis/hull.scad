// M1A1 Abrams — Hull Chassis (1:26 scale, Gemini-verified proportions)
// Split into front and rear halves for Bambu A1 Mini build volume
// Integrated: hull camera mount, slip-ring void, electronics bay mounting
//
// Key shape notes (Tank Encyclopedia + Gemini):
// - Hull is VERY flat and wide (139mm x 55mm cross-section)
// - Front has a BEAK: lower plate slopes down, upper glacis is near-vertical (82.5 deg)
// - Upper hull sides slope inward above the deck line
// - Full-length side skirts covering track system

use <../libs/common.scad>
use <../libs/m4_hardware.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

// --- Hull Parameters (1:26 scale from real M1A1) ---
hull_length = 150;          // Per half (total 300mm)
hull_width = 139;           // Was 90 — real M1A1 is very wide between tracks
hull_height = 55;           // Was 80 — real M1A1 is very flat
wall = 1.6;                 // Structural walls (min 1.6mm for strength)

// Glacis plate — M1A1 has near-vertical upper plate with a beak
glacis_angle = 82.5;        // Degrees from horizontal (was 30) — almost vertical

// Turret ring (real 2159mm OD / 26.4 scale)
turret_ring_od = 82;        // Was 100
turret_ring_id = 74;        // Was 92
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

// Hull camera (ESP32-CAM: 40x27x12mm)
hull_cam_width = 30;            // Window width
hull_cam_height = 20;           // Window height (reduced — hull is flatter now)

// Electronics bay mounting (4x M3 in rear hull floor)
ebay_mount_inset = 6;
ebay_mount_x = 138;             // Electronics bay length
ebay_mount_y = 133;             // Was 86 — scaled to new hull_width (hull_width - 2*wall ~= 136)

// Part selector — set via CLI: -D 'part="front"'
part = "assembly";  // "front" | "rear" | "assembly"

// --- M1A1 Hull Shape Parameters ---
upper_taper = 12;          // Was 8 — more inward slope on upper armor
deck_height = hull_height * 0.55;  // Where the upper hull starts tapering (was 0.6)
side_skirt_drop = 15;      // Was 10 — longer side skirts covering tracks
rear_slope = 15;           // Rear deck slope angle

// Beak geometry — the distinctive M1A1 front
beak_drop = 18;            // How far the beak drops below the hull bottom
beak_length = 35;          // How far the beak extends forward from hull face
beak_tip_height = 4;       // Thickness at the beak tip

// --- Hull Shape Module ---
// Cross-section: flat bottom, vertical lower sides, tapered upper sides, flat deck
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

    // Side skirts — full-length plates covering track system
    for (y_pos = [-2, hull_width])
        translate([0, y_pos, -side_skirt_drop])
            cube([length, 2, deck_height + side_skirt_drop]);
}

// --- Beak + Glacis ---
// M1A1 front: lower beak slopes downward, upper glacis is near-vertical
module glacis_plate() {
    // The beak: triangular wedge sloping downward from hull front
    // Forms the distinctive M1A1 "beak" shape
    hull() {
        // Top edge of beak at hull front face, at about deck_height
        translate([0, wall, 0])
            cube([wall, hull_width - 2*wall, deck_height]);
        // Beak tip — extends forward and drops below hull bottom
        translate([-beak_length, hull_width * 0.15, -beak_drop])
            cube([wall, hull_width * 0.7, beak_tip_height]);
    }

    // Upper glacis — near-vertical plate above the beak
    // At 82.5 degrees from horizontal, the horizontal setback is tiny:
    // hull_height_above_deck * cos(82.5) ~= (hull_height - deck_height) * 0.13
    glacis_setback = (hull_height - deck_height) / tan(glacis_angle);
    hull() {
        // Bottom edge at deck_height on the hull face
        translate([0, wall, deck_height])
            cube([wall, hull_width - 2*wall, 0.1]);
        // Top edge — slightly forward of hull face due to steep angle
        translate([-glacis_setback, upper_taper, hull_height - 0.1])
            cube([wall, hull_width - 2*upper_taper, 0.1]);
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
    // Centered in hull width, positioned in upper half of hull face
    // ESP32-CAM is 40x27x12mm — hull_width=139 gives plenty of centering room
    translate([wall + 2, hull_width/2 - 13.5, hull_height * 0.4 + 2])
        esp32cam_mount(standoff_h=3);
}

// --- Front Hull Half ---
module hull_front() {
    difference() {
        union() {
            hull_shape(hull_length);
            glacis_plate();
            hull_cam_mount();
        }

        // ESP32-CAM front window (lens aperture)
        // Positioned to match camera mount height
        translate([-beak_length - 0.1, hull_width/2 - hull_cam_width/2, hull_height * 0.4])
            cube([beak_length + wall + 5, hull_cam_width, hull_cam_height]);
    }

    // Motor mounts (front pair — one per side)
    for (side = [0, 1])
        translate([20, side * (hull_width - motor_mount_width), 0])
            motor_mount();

    // Split joint — alignment keys (at hull_length face, mating with rear half)
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

// --- Electronics Bay Floor Mounts ---
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

// --- Rear Hull Half ---
module hull_rear() {
    difference() {
        hull_shape(hull_length);

        // Split joint — alignment sockets (mating with front half keys)
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

// --- Full Assembly (both halves) ---
module hull_assembly() {
    hull_front();
    translate([hull_length, 0, 0])
        hull_rear();
}

// Render selected part
if (part == "front") hull_front();
else if (part == "rear") hull_rear();
else if (part == "assembly") hull_assembly();
