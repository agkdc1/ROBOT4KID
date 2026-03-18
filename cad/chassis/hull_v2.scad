// M1A1 Abrams — Hull Chassis v2 (1:18 scale)
// BLOCKOUT — simple primitives only (Step 2)
// Split into 3 lengthwise pieces, each printed diagonally on Bambu A1 Mini
//
// Real M1A1 hull: 7917 x 3658 x 1092 mm
// At 1/18:        440  x 203  x 61   mm
//
// Split: front (147mm) | center (146mm) | rear (147mm)
// Width 203mm fits 180x180 bed diagonally (diagonal capacity ~254mm)
//
// Part selector: set via CLI with -D 'part="front"'

$fn = 32;

// =====================================================================
// PARAMETERS
// =====================================================================

// --- Hull Dimensions (1:18 scale) ---
hull_length     = 440;
hull_width      = 203;
hull_height     = 61;
wall            = 2.5;      // Child-safe wall thickness
floor_t         = 2.0;      // Floor thickness

// --- Split Boundaries ---
front_len       = 147;
center_len      = 146;
rear_len        = 147;

// --- Glacis Plate ---
glacis_angle    = 82.5;     // Near-vertical upper glacis (degrees from horizontal)
beak_drop       = 28;       // Beak drops below hull bottom (scaled from 1/26)
beak_length     = 30;       // Forward beak extension
beak_tip_h      = 4;        // Thickness at beak tip

// --- Turret Ring (real 2159mm OD / 18) ---
turret_ring_od  = 120;      // ~2159/18 = 120mm
turret_ring_id  = 112;
turret_ring_h   = 8;

// --- Slip Ring ---
slip_ring_od    = 22;       // Wire pass-through to turret

// --- Hull Camera (ESP32-CAM: 40x27x12mm) ---
hull_cam_w      = 30;       // Window width in glacis
hull_cam_h      = 20;       // Window height in glacis

// --- Motor Mounts (N20: 12mm dia x 25mm long) ---
n20_dia         = 12;
n20_len         = 25;
motor_mount_w   = 16;       // Clamp cradle width
motor_mount_d   = 30;       // Depth of mount block
motor_mount_h   = 20;       // Height of mount block

// --- Battery (2x 18650 case: 77x41x20mm) ---
battery_l       = 77;
battery_w       = 41;
battery_h       = 20;

// --- Electronics Components ---
// DROK buck converter
drok_l          = 46;
drok_w          = 28;
drok_h          = 14;

// 2-to-8 lever-nut power bus
levernut_bus_l  = 40;
levernut_bus_w  = 20;
levernut_bus_h  = 18;

// L9110S motor driver
l9110s_l        = 29;
l9110s_w        = 23;
l9110s_h        = 15;

// ESP32-CAM + MB adapter stack
esp32cam_l      = 40;
esp32cam_w      = 27;
esp32cam_h      = 25;       // Combined stack height

// MPU-6050 IMU
mpu_l           = 21;
mpu_w           = 16;
mpu_h           = 3;

// Wago 221-415 connectors
wago_l          = 20;
wago_w          = 13;
wago_h          = 16;
wago_count      = 6;        // Minimum 6 connector pockets
wago_air        = 1.2;      // 20% air space on each side (~20% of 13mm/2)

// --- Wire Channels ---
wire_ch_w       = 10;       // Channel width
wire_ch_h       = 8;        // Channel depth

// --- Bolt Joints ---
// M4 bolts between hull pieces: 4 per seam = 8 total
m4_hole_dia     = 4.4;      // M4 through-hole with clearance
bolt_inset      = 12;       // Distance from edge to bolt center
bolt_tab_w      = 16;       // Width of bolt tab
bolt_tab_h      = 12;       // Height of bolt tab (vertical)

// --- Track Attachment ---
track_bolt_spacing = 40;    // M4 bolt spacing along sides
track_bolt_count   = 8;     // Per side (distributed across all 3 sections)

// --- Engine Deck Louvers ---
louver_count    = 12;
louver_w        = 2;
louver_spacing  = 8;
louver_len      = 50;

// --- Part Selector ---
part = "assembly";  // "assembly" | "front" | "center" | "rear" | "hatch"

// =====================================================================
// HELPER MODULES
// =====================================================================

// Simple box with optional center flag
module box(size, center=false) {
    if (center)
        translate(-size/2) cube(size);
    else
        cube(size);
}

// Ghost volume — translucent red for electronics visualization
module ghost(size) {
    %color("red", 0.15) cube(size);
}

// M4 bolt hole (vertical, through full height)
module m4_bolt_hole(depth=20) {
    cylinder(d=m4_hole_dia, h=depth, center=true);
}

// =====================================================================
// HULL FRONT (0 to 147mm)
// =====================================================================
module hull_front() {
    color("OliveDrab", 0.8)
    difference() {
        union() {
            // --- Main box ---
            cube([front_len, hull_width, hull_height]);

            // --- Glacis beak (angled front armor) ---
            // Simple wedge: drops below hull bottom at the front
            translate([0, 0, -beak_drop])
            hull() {
                // Tip of beak (thin edge at very front)
                translate([0, wall, 0])
                    cube([1, hull_width - 2*wall, beak_tip_h]);
                // Where beak meets hull body
                translate([beak_length, 0, beak_drop])
                    cube([1, hull_width, hull_height]);
            }
        }

        // --- Hollow interior ---
        translate([wall, wall, floor_t])
            cube([front_len - wall + 1, hull_width - 2*wall, hull_height - floor_t - wall]);

        // --- Hull camera window (centered on glacis) ---
        translate([-1, hull_width/2 - hull_cam_w/2, hull_height/2 - hull_cam_h/2])
            cube([wall + 2, hull_cam_w, hull_cam_h]);

        // --- Wire channel (along bottom, exits to center section) ---
        translate([front_len - 1, hull_width/2 - wire_ch_w/2, floor_t])
            cube([2, wire_ch_w, wire_ch_h]);

        // --- Bolt holes at rear seam (connects to center) ---
        for (i = [0:3]) {
            bx = front_len;
            by = bolt_inset + i * ((hull_width - 2*bolt_inset) / 3);
            bz = hull_height / 2;
            translate([bx, by, bz])
                rotate([0, 90, 0])
                    m4_bolt_hole(30);
        }

        // --- Track attachment bolt holes (M4 along left side) ---
        for (i = [0:2]) {
            tx = 30 + i * track_bolt_spacing;
            // Left side
            translate([tx, -1, hull_height/2])
                rotate([-90, 0, 0])
                    m4_bolt_hole(wall + 2);
            // Right side
            translate([tx, hull_width - wall - 1, hull_height/2])
                rotate([-90, 0, 0])
                    m4_bolt_hole(wall + 2);
        }
    }

    // --- N20 motor mounts (2x, one per side) ---
    // Left motor mount
    translate([20, wall + 5, floor_t])
        motor_mount_block();
    // Right motor mount
    translate([20, hull_width - wall - 5 - motor_mount_w, floor_t])
        motor_mount_block();

    // --- ESP32-CAM hull camera mount (internal cradle) ---
    translate([wall + 2, hull_width/2 - esp32cam_w/2, floor_t])
        hull_camera_mount();
}

// =====================================================================
// HULL CENTER (147 to 293mm)
// =====================================================================
module hull_center() {
    color("OliveDrab", 0.7)
    difference() {
        union() {
            // --- Main box ---
            cube([center_len, hull_width, hull_height]);

            // --- Turret ring (raised ring on top) ---
            translate([center_len/2, hull_width/2, hull_height])
                cylinder(d=turret_ring_od, h=turret_ring_h);
        }

        // --- Hollow interior ---
        translate([wall, wall, floor_t])
            cube([center_len - 2*wall, hull_width - 2*wall, hull_height - floor_t - wall]);

        // --- Turret ring bore ---
        translate([center_len/2, hull_width/2, hull_height - 1])
            cylinder(d=turret_ring_id, h=turret_ring_h + 2);

        // --- Slip ring hole (centered in turret ring) ---
        translate([center_len/2, hull_width/2, -1])
            cylinder(d=slip_ring_od, h=hull_height + turret_ring_h + 2);

        // --- Battery hatch cutout (bottom, centered) ---
        translate([center_len/2 - battery_l/2 - 5,
                   hull_width/2 - battery_w/2 - 5,
                   -1])
            cube([battery_l + 10, battery_w + 10, floor_t + 2]);

        // --- Wire channels (front and rear exits) ---
        // Front exit
        translate([-1, hull_width/2 - wire_ch_w/2, floor_t])
            cube([2, wire_ch_w, wire_ch_h]);
        // Rear exit
        translate([center_len - 1, hull_width/2 - wire_ch_w/2, floor_t])
            cube([2, wire_ch_w, wire_ch_h]);

        // --- Bolt holes at front seam ---
        for (i = [0:3]) {
            by = bolt_inset + i * ((hull_width - 2*bolt_inset) / 3);
            translate([0, by, hull_height/2])
                rotate([0, 90, 0])
                    m4_bolt_hole(30);
        }

        // --- Bolt holes at rear seam ---
        for (i = [0:3]) {
            by = bolt_inset + i * ((hull_width - 2*bolt_inset) / 3);
            translate([center_len, by, hull_height/2])
                rotate([0, 90, 0])
                    m4_bolt_hole(30);
        }

        // --- Track attachment bolt holes ---
        for (i = [0:2]) {
            tx = 25 + i * track_bolt_spacing;
            // Left
            translate([tx, -1, hull_height/2])
                rotate([-90, 0, 0])
                    m4_bolt_hole(wall + 2);
            // Right
            translate([tx, hull_width - wall - 1, hull_height/2])
                rotate([-90, 0, 0])
                    m4_bolt_hole(wall + 2);
        }

        // --- Wago connector pockets (recessed bays with 20% air space) ---
        // Row of 3 along left interior wall
        for (i = [0:2]) {
            translate([15 + i * 35,
                       wall - 1,
                       floor_t + 5])
                cube([wago_l + 2*wago_air, wall + 2, wago_h + 2*wago_air]);
        }
        // Row of 3 along right interior wall
        for (i = [0:2]) {
            translate([15 + i * 35,
                       hull_width - 2*wall - 1,
                       floor_t + 5])
                cube([wago_l + 2*wago_air, wall + 2, wago_h + 2*wago_air]);
        }
    }

    // --- Internal wire channels (raised guides along floor edges) ---
    wire_channels_center();

    // --- Electronics ghost volumes (visualization only) ---
    electronics_layout();
}

// =====================================================================
// HULL REAR (293 to 440mm)
// =====================================================================
module hull_rear() {
    color("OliveDrab", 0.6)
    difference() {
        // --- Main box ---
        cube([rear_len, hull_width, hull_height]);

        // --- Hollow interior ---
        translate([wall, wall, floor_t])
            cube([rear_len - wall + 1, hull_width - 2*wall, hull_height - floor_t - wall]);

        // --- Engine deck louvers (cut through top) ---
        for (i = [0:louver_count-1]) {
            translate([20 + i * louver_spacing,
                       hull_width/2 - louver_len/2,
                       hull_height - wall - 1])
                cube([louver_w, louver_len, wall + 2]);
        }

        // --- Wire channel exit to center section ---
        translate([-1, hull_width/2 - wire_ch_w/2, floor_t])
            cube([2, wire_ch_w, wire_ch_h]);

        // --- Bolt holes at front seam (connects to center) ---
        for (i = [0:3]) {
            by = bolt_inset + i * ((hull_width - 2*bolt_inset) / 3);
            translate([0, by, hull_height/2])
                rotate([0, 90, 0])
                    m4_bolt_hole(30);
        }

        // --- Track attachment bolt holes ---
        for (i = [0:2]) {
            tx = 20 + i * track_bolt_spacing;
            // Left
            translate([tx, -1, hull_height/2])
                rotate([-90, 0, 0])
                    m4_bolt_hole(wall + 2);
            // Right
            translate([tx, hull_width - wall - 1, hull_height/2])
                rotate([-90, 0, 0])
                    m4_bolt_hole(wall + 2);
        }
    }

    // --- N20 motor mounts (2x, rear pair) ---
    translate([rear_len - 50, wall + 5, floor_t])
        motor_mount_block();
    translate([rear_len - 50, hull_width - wall - 5 - motor_mount_w, floor_t])
        motor_mount_block();
}

// =====================================================================
// BATTERY HATCH (separate piece, clips under hull center)
// =====================================================================
module battery_hatch() {
    hatch_l = battery_l + 10;
    hatch_w = battery_w + 10;
    color("DarkOliveGreen", 0.9)

    difference() {
        union() {
            // --- Hatch plate ---
            cube([hatch_l, hatch_w, floor_t]);

            // --- Retention lip (raised rim around edge for alignment) ---
            translate([0, 0, floor_t])
            difference() {
                cube([hatch_l, hatch_w, 3]);
                translate([2, 2, -1])
                    cube([hatch_l - 4, hatch_w - 4, 5]);
            }
        }

        // --- M3 screw lock holes (2x, diagonal corners) ---
        translate([8, 8, -1])
            cylinder(d=3.4, h=floor_t + 5);
        translate([hatch_l - 8, hatch_w - 8, -1])
            cylinder(d=3.4, h=floor_t + 5);
    }
}

// =====================================================================
// SLIP RING MOUNT (centered in turret ring)
// =====================================================================
module slip_ring_mount() {
    color("Gray", 0.7)
    // Simple collar that sits in the turret ring bore
    difference() {
        cylinder(d=slip_ring_od + 6, h=turret_ring_h + 5);
        translate([0, 0, -1])
            cylinder(d=slip_ring_od, h=turret_ring_h + 7);
    }
}

// =====================================================================
// ELECTRONICS LAYOUT (ghost volumes — visualization only)
// Positioned inside hull center, origin at hull_center origin
// =====================================================================
module electronics_layout() {
    // All positions relative to hull center interior
    // Interior starts at (wall, wall, floor_t)
    int_x = wall;
    int_y = wall;
    int_z = floor_t;

    // --- Top row (front-to-back along one side) ---

    // ESP32-CAM + MB stack (front-left)
    translate([int_x + 5, int_y + 5, int_z])
        ghost([esp32cam_l, esp32cam_w, esp32cam_h]);

    // DROK buck converter (next to ESP32-CAM)
    translate([int_x + 5 + esp32cam_l + 5, int_y + 5, int_z])
        ghost([drok_l, drok_w, drok_h]);

    // Lever-nut 2-to-8 power bus
    translate([int_x + 5 + esp32cam_l + 5 + drok_l + 5, int_y + 5, int_z])
        ghost([levernut_bus_l, levernut_bus_w, levernut_bus_h]);

    // L9110S motor driver (far right in row)
    l9110s_x = int_x + 5 + esp32cam_l + 5 + drok_l + 5 + levernut_bus_l + 5;
    translate([l9110s_x, int_y + 5, int_z])
        ghost([l9110s_l, l9110s_w, l9110s_h]);

    // --- Center: MPU-6050 at geometric center ---
    translate([center_len/2 - mpu_l/2, hull_width/2 - mpu_w/2, int_z])
        ghost([mpu_l, mpu_w, mpu_h]);

    // --- Bottom: Battery case (centered, accessible from hatch) ---
    translate([center_len/2 - battery_l/2, hull_width/2 - battery_w/2, int_z])
        color("blue", 0.2) cube([battery_l, battery_w, battery_h]);

    // --- Wago connectors (6x distributed along walls) ---
    // Left wall: 3 Wagos
    for (i = [0:2]) {
        translate([15 + i * 35, int_y, int_z + 5])
            color("orange", 0.2) cube([wago_l, wago_w, wago_h]);
    }
    // Right wall: 3 Wagos
    for (i = [0:2]) {
        translate([15 + i * 35, hull_width - wall - wago_w, int_z + 5])
            color("orange", 0.2) cube([wago_l, wago_w, wago_h]);
    }
}

// =====================================================================
// WIRE CHANNELS (raised guides inside hull center floor)
// =====================================================================
module wire_channels_center() {
    int_z = floor_t;
    guide_h = 5;   // Height of channel guide walls
    guide_t = 1.5; // Thickness of guide wall

    color("OliveDrab", 0.5) {
        // Left-side channel (runs front-to-back along left wall)
        translate([0, wall + 2, int_z]) {
            cube([center_len, guide_t, guide_h]);                // Inner wall
            translate([0, wire_ch_w + guide_t, 0])
                cube([center_len, guide_t, guide_h]);            // Outer wall
        }

        // Right-side channel (mirror)
        translate([0, hull_width - wall - 2 - wire_ch_w - 2*guide_t, int_z]) {
            cube([center_len, guide_t, guide_h]);
            translate([0, wire_ch_w + guide_t, 0])
                cube([center_len, guide_t, guide_h]);
        }

        // Cross channel (connects left to right, for power distribution)
        translate([center_len/2 - wire_ch_w/2, wall, int_z]) {
            cube([guide_t, hull_width - 2*wall, guide_h]);
            translate([wire_ch_w + guide_t, 0, 0])
                cube([guide_t, hull_width - 2*wall, guide_h]);
        }
    }
}

// =====================================================================
// CONNECTOR POCKETS (recessed bays for Wago/lever-nut with air space)
// Built into hull_center walls via difference() above
// This module provides the positive form for reference
// =====================================================================
module connector_pocket() {
    // Single pocket: wago dimensions + 20% air space
    cube([wago_l + 2*wago_air,
          wago_w + 2*wago_air,
          wago_h + 2*wago_air]);
}

// =====================================================================
// MOTOR MOUNT BLOCK (N20 clamp cradle — simple blockout)
// =====================================================================
module motor_mount_block() {
    color("DarkGray", 0.5)
    difference() {
        // Mount block
        cube([motor_mount_d, motor_mount_w, motor_mount_h]);

        // Motor bore (horizontal cylinder through center)
        translate([-1, motor_mount_w/2, motor_mount_h/2 + 2])
            rotate([0, 90, 0])
                cylinder(d=n20_dia + 0.4, h=motor_mount_d + 2);

        // Clamp slit (allows compression fit)
        translate([motor_mount_d/2, motor_mount_w/2, motor_mount_h/2 + 2])
            translate([0, 0, n20_dia/2 - 1])
                cube([motor_mount_d + 2, 1.5, motor_mount_h], center=true);
    }
}

// =====================================================================
// HULL CAMERA MOUNT (ESP32-CAM cradle behind glacis window)
// =====================================================================
module hull_camera_mount() {
    // Simple U-shaped cradle
    cradle_d = 15;
    cradle_w = esp32cam_w + 1;  // Slight clearance
    cradle_h = esp32cam_h + 5;
    color("DarkGray", 0.5)

    difference() {
        cube([cradle_d, cradle_w, cradle_h]);
        // Camera slot
        translate([2, 0.5, 2])
            cube([cradle_d - 2, esp32cam_w, esp32cam_h]);
    }
}

// =====================================================================
// FULL ASSEMBLY
// =====================================================================
module hull_assembly() {
    // Front section at origin
    hull_front();

    // Center section
    translate([front_len, 0, 0])
        hull_center();

    // Rear section
    translate([front_len + center_len, 0, 0])
        hull_rear();

    // Battery hatch (under center section)
    translate([front_len + center_len/2 - (battery_l + 10)/2,
               hull_width/2 - (battery_w + 10)/2,
               -floor_t])
        battery_hatch();

    // Slip ring mount (centered on turret ring)
    translate([front_len + center_len/2,
               hull_width/2,
               hull_height])
        slip_ring_mount();
}

// =====================================================================
// PART SELECTOR — render individual pieces or full assembly
// =====================================================================

if (part == "assembly") {
    hull_assembly();
} else if (part == "front") {
    hull_front();
} else if (part == "center") {
    hull_center();
} else if (part == "rear") {
    hull_rear();
} else if (part == "hatch") {
    battery_hatch();
} else {
    echo("ERROR: Unknown part selector. Use: assembly | front | center | rear | hatch");
    hull_assembly();
}
