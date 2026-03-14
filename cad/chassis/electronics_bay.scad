// M1A1 Abrams — Electronics Bay / Internal Tray
// Removable tray that sits on rear hull floor, houses all electronics
// Fits within hull interior: 90mm wide, up to 140mm long, 80mm tall

use <../libs/common.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

// --- Part Selector ---
// Set via CLI: -D 'part="tray"'
part = "assembly";  // "tray" | "assembly"

// --- Tray Dimensions ---
tray_length   = 138;           // Fits in rear hull half with clearance
tray_width    = 86;            // Hull interior 90 - 2*tolerance
tray_height   = 74;            // Hull interior 80 - wall(1.6) - clearance
tray_wall     = 1.6;           // Structural wall thickness
tray_floor    = 1.6;           // Floor thickness
tray_corner_r = 2;             // Corner radius

// --- Component Dimensions ---
// ESP32 on Terminal Shield
esp32_l       = 85;
esp32_w       = 65;
esp32_h       = 18;            // Board + components height
esp32_standoff = 8;            // M3 standoff height
esp32_clearance = 20;          // Wiring clearance above

// L298N Motor Driver
l298n_l       = 43;
l298n_w       = 43;
l298n_h       = 28;            // Board + heatsink height
l298n_standoff = 3;            // Low standoffs, heatsink needs air
l298n_clearance = 20;          // Above screw terminals

// LM2596 Buck Converter
lm2596_l      = 43;
lm2596_w      = 21;
lm2596_h      = 12;
lm2596_standoff = 3;

// 18650 Battery Holder (2S)
batt_l        = 77;
batt_w        = 41;
batt_h        = 22;
batt_lip      = 3;            // Retaining lip height
batt_lip_t    = 1.2;          // Lip thickness

// WAGO Connectors
wago_l        = 20;
wago_w        = 13;
wago_h        = 15;
wago_count    = 3;
wago_spacing  = 2;

// MPU-6050 IMU
imu_l         = 21;
imu_w         = 16;
imu_h         = 3;
imu_standoff  = 3;            // M2.5 low-profile standoffs

// --- Wire Duct Parameters ---
duct_width    = 10;
duct_depth    = 8;

// --- Slip-Ring Void ---
slip_ring_dia = 22;

// --- Ventilation Slots ---
vent_count    = 6;
vent_length   = 15;
vent_width    = 3;
vent_spacing  = 5;

// --- Component Positions (from tray origin, bottom-left-rear corner) ---
// All positions are [x, y] on tray floor (z = tray_floor)

// ESP32 — center of bay, elevated on standoffs
esp32_x       = (tray_length - esp32_l) / 2;
esp32_y       = (tray_width - esp32_w) / 2;

// L298N — near rear wall (x=0 is rear), close to motor wire exits
l298n_x       = 4;
l298n_y       = tray_width - l298n_w - tray_wall - 2;

// LM2596 — next to battery holder, short power run
lm2596_x      = 4;
lm2596_y      = tray_wall + 2;

// Battery holder — along left side wall
batt_x        = lm2596_x + lm2596_l + 4;
batt_y        = tray_wall + 1;

// WAGO connectors — between LM2596 and battery, near power components
wago_x        = 4;
wago_y        = lm2596_y + lm2596_w + 3;

// IMU — center of hull floor for best readings
imu_x         = (tray_length - imu_l) / 2;
imu_y         = (tray_width - imu_w) / 2;

// --- Mounting Holes (4 corners, M3 to hull floor) ---
mount_inset   = 6;             // From tray edge

// --- Zip-Tie Anchor Dimensions ---
zt_width      = 4;
zt_slot_h     = 2;
zt_post_h     = 6;
zt_post_w     = 3;

$fn = 64;

// =====================================================================
// Modules
// =====================================================================

module tray_base() {
    // Floor plate with raised walls
    difference() {
        rounded_cube([tray_length, tray_width, tray_height], r=tray_corner_r);

        // Hollow interior
        translate([tray_wall, tray_wall, tray_floor])
            cube([
                tray_length - 2 * tray_wall,
                tray_width  - 2 * tray_wall,
                tray_height  // Open top
            ]);
    }
}

module m3_mount_bosses() {
    // 4 corner mounting bosses with M3 through-holes
    boss_d = 7;
    boss_h = tray_floor;
    positions = [
        [mount_inset,                mount_inset],
        [tray_length - mount_inset,  mount_inset],
        [mount_inset,                tray_width - mount_inset],
        [tray_length - mount_inset,  tray_width - mount_inset]
    ];
    for (p = positions) {
        // Boss cylinder (reinforcement around hole)
        translate([p[0], p[1], 0])
            cylinder(h=tray_floor + 2, d=boss_d);
    }
}

module m3_mount_holes() {
    // Through-holes at 4 corners for M3 mounting screws
    positions = [
        [mount_inset,                mount_inset],
        [tray_length - mount_inset,  mount_inset],
        [mount_inset,                tray_width - mount_inset],
        [tray_length - mount_inset,  tray_width - mount_inset]
    ];
    for (p = positions) {
        translate([p[0], p[1], -0.05])
            m3_countersink(depth=tray_floor + 2.2);
    }
}

module esp32_standoffs() {
    // 4x M3 standoffs for ESP32 terminal shield
    // Hole pattern: corners of 85x65 board, inset 3mm
    inset = 3;
    positions = [
        [esp32_x + inset,            esp32_y + inset],
        [esp32_x + esp32_l - inset,  esp32_y + inset],
        [esp32_x + inset,            esp32_y + esp32_w - inset],
        [esp32_x + esp32_l - inset,  esp32_y + esp32_w - inset]
    ];
    for (p = positions) {
        translate([p[0], p[1], tray_floor])
            m3_pcb_standoff(height=esp32_standoff);
    }
}

module l298n_standoffs() {
    // 4x M3 standoffs for L298N
    inset = 3;
    positions = [
        [l298n_x + inset,            l298n_y + inset],
        [l298n_x + l298n_l - inset,  l298n_y + inset],
        [l298n_x + inset,            l298n_y + l298n_w - inset],
        [l298n_x + l298n_l - inset,  l298n_y + l298n_w - inset]
    ];
    for (p = positions) {
        translate([p[0], p[1], tray_floor])
            m3_pcb_standoff(height=l298n_standoff);
    }
}

module lm2596_standoffs() {
    // 2x M3 standoffs for LM2596 (only 2 holes on this board)
    inset = 3;
    positions = [
        [lm2596_x + inset,              lm2596_y + lm2596_w / 2],
        [lm2596_x + lm2596_l - inset,   lm2596_y + lm2596_w / 2]
    ];
    for (p = positions) {
        translate([p[0], p[1], tray_floor])
            m3_pcb_standoff(height=lm2596_standoff);
    }
}

module battery_cradle() {
    // Friction-fit cradle with retaining lips
    cradle_wall = 1.6;
    cradle_h = batt_h + batt_lip;

    translate([batt_x, batt_y, tray_floor]) {
        difference() {
            // Outer cradle
            cube([batt_l + 2 * cradle_wall, batt_w + 2 * cradle_wall, cradle_h]);
            // Inner cavity
            translate([cradle_wall, cradle_wall, cradle_wall])
                cube([batt_l, batt_w, cradle_h]);
        }

        // Retaining lips (inward-facing ledges at top, two sides)
        for (side = [0, 1]) {
            // Long sides
            translate([cradle_wall, side * (batt_w + cradle_wall), batt_h + cradle_wall])
                cube([batt_l, batt_lip_t, batt_lip]);
        }
        // Short sides
        for (end = [0, 1]) {
            translate([end * (batt_l + cradle_wall), cradle_wall, batt_h + cradle_wall])
                cube([batt_lip_t, batt_w, batt_lip]);
        }
    }
}

module wago_holders() {
    // Friction-fit slots for WAGO 221 lever connectors
    holder_wall = 1.2;
    holder_h = wago_h + 2;

    translate([wago_x, wago_y, tray_floor]) {
        for (i = [0 : wago_count - 1]) {
            y_off = i * (wago_w + wago_spacing + 2 * holder_wall);
            translate([0, y_off, 0]) {
                difference() {
                    cube([wago_l + 2 * holder_wall, wago_w + 2 * holder_wall, holder_h]);
                    translate([holder_wall, holder_wall, holder_wall])
                        cube([wago_l, wago_w, holder_h]);
                }
            }
        }
    }
}

module imu_standoffs() {
    // 4x M2.5 standoffs for MPU-6050 — center of floor
    inset = 2;
    positions = [
        [imu_x + inset,            imu_y + inset],
        [imu_x + imu_l - inset,    imu_y + inset],
        [imu_x + inset,            imu_y + imu_w - inset],
        [imu_x + imu_l - inset,    imu_y + imu_w - inset]
    ];
    for (p = positions) {
        translate([p[0], p[1], tray_floor])
            m25_standoff(height=imu_standoff, outer_dia=5.5);
    }
}

module wire_ducts() {
    // Open-top channels between component areas
    translate([0, 0, tray_floor]) {
        // Duct 1: ESP32 to L298N (rear, along Y axis)
        translate([l298n_x + l298n_l + 2, l298n_y + l298n_w / 2 - duct_width / 2, 0])
            cube([esp32_x - l298n_x - l298n_l - 2, duct_width, duct_depth]);

        // Duct 2: ESP32 to battery/LM2596 area (left side)
        translate([esp32_x - 2 - duct_width, esp32_y, 0])
            cube([duct_width, esp32_w / 2, duct_depth]);

        // Duct 3: Power rail — LM2596 to WAGO to battery (along rear wall)
        translate([lm2596_x, lm2596_y + lm2596_w, 0])
            cube([batt_x + batt_l - lm2596_x, duct_width, duct_depth]);

        // Duct 4: Central duct under ESP32 to IMU
        translate([imu_x + imu_l, imu_y + imu_w / 2 - duct_width / 2, 0])
            cube([esp32_x - imu_x - imu_l + 5, duct_width, duct_depth]);
    }
}

module zip_tie_anchors() {
    // Zip-tie pass-through posts at strategic routing points
    positions = [
        // Near ESP32 corners
        [esp32_x - 3,              esp32_y + esp32_w / 2],
        [esp32_x + esp32_l + 3,    esp32_y + esp32_w / 2],
        // Near L298N output
        [l298n_x + l298n_l + 2,    l298n_y + l298n_w - 5],
        // Near battery holder
        [batt_x + batt_l + 2,      batt_y + batt_w / 2],
        // Near WAGO area
        [wago_x + wago_l + 5,      wago_y + 5],
        // Near IMU
        [imu_x - 3,                imu_y + imu_w / 2]
    ];

    for (p = positions) {
        translate([p[0], p[1], tray_floor]) {
            // Two posts with a gap for the zip-tie
            for (dx = [-zt_post_w, zt_post_w]) {
                translate([dx, -zt_post_w / 2, 0])
                    cube([zt_post_w, zt_post_w, zt_post_h]);
            }
        }
    }
}

module slip_ring_void() {
    // 22mm void at center top for slip-ring / turret wiring pass-through
    // Aligned with turret ring center (center of tray)
    translate([tray_length / 2, tray_width / 2, -0.05])
        cylinder(h=tray_floor + 0.1, d=slip_ring_dia + 1);
}

module ventilation_slots() {
    // Vertical slots in tray wall near L298N heatsink
    slot_start_z = tray_floor + l298n_standoff + 5;
    wall_x = tray_wall;  // Rear wall of tray

    // Slots in the side wall nearest to L298N heatsink
    for (i = [0 : vent_count - 1]) {
        z_off = slot_start_z + i * (vent_width + vent_spacing);
        // Rear wall slots
        translate([-0.05, l298n_y + 5 + i * (vent_width + vent_spacing), tray_floor + 10])
            cube([tray_wall + 0.1, vent_width, vent_length]);
    }

    // Side wall slots (Y-max wall, where heatsink faces)
    for (i = [0 : vent_count - 1]) {
        translate([l298n_x + 3 + i * (vent_width + vent_spacing),
                   tray_width - tray_wall - 0.05,
                   tray_floor + 10])
            cube([vent_width, tray_wall + 0.1, vent_length]);
    }
}

// =====================================================================
// Main Tray Assembly
// =====================================================================

module electronics_tray() {
    difference() {
        union() {
            tray_base();
            m3_mount_bosses();
            esp32_standoffs();
            l298n_standoffs();
            lm2596_standoffs();
            imu_standoffs();
            battery_cradle();
            wago_holders();
            zip_tie_anchors();
        }

        // Subtractive features
        m3_mount_holes();
        slip_ring_void();
        ventilation_slots();
    }

    // Wire ducts are additive (raised channel walls on floor)
    // Rendered as guide ribs on the floor
    wire_duct_walls();
}

module wire_duct_walls() {
    // Raised walls forming open-top wire channels
    rib_h = duct_depth;
    rib_t = 1.2;

    translate([0, 0, tray_floor]) {
        // Duct 1 walls: ESP32 to L298N
        duct1_x0 = l298n_x + l298n_l + 2;
        duct1_x1 = esp32_x;
        duct1_y  = l298n_y + l298n_w / 2;
        // Left wall
        translate([duct1_x0, duct1_y - duct_width / 2 - rib_t, 0])
            cube([duct1_x1 - duct1_x0, rib_t, rib_h]);
        // Right wall
        translate([duct1_x0, duct1_y + duct_width / 2, 0])
            cube([duct1_x1 - duct1_x0, rib_t, rib_h]);

        // Duct 3 walls: Power rail
        duct3_y0 = lm2596_y + lm2596_w;
        // Left wall
        translate([lm2596_x, duct3_y0, 0])
            cube([batt_x + batt_l - lm2596_x, rib_t, rib_h]);
        // Right wall
        translate([lm2596_x, duct3_y0 + duct_width, 0])
            cube([batt_x + batt_l - lm2596_x, rib_t, rib_h]);
    }
}

// =====================================================================
// Dummy Components (for assembly visualization)
// =====================================================================

module dummy_esp32() {
    color("DarkGreen", 0.7)
    translate([esp32_x, esp32_y, tray_floor + esp32_standoff])
        cube([esp32_l, esp32_w, esp32_h]);
}

module dummy_l298n() {
    color("Red", 0.7)
    translate([l298n_x, l298n_y, tray_floor + l298n_standoff])
        cube([l298n_l, l298n_w, l298n_h]);
}

module dummy_lm2596() {
    color("Blue", 0.7)
    translate([lm2596_x, lm2596_y, tray_floor + lm2596_standoff])
        cube([lm2596_l, lm2596_w, lm2596_h]);
}

module dummy_battery() {
    color("Orange", 0.7)
    translate([batt_x + 1.6, batt_y + 1.6, tray_floor + 1.6])
        cube([batt_l, batt_w, batt_h]);
}

module dummy_wago() {
    holder_wall = 1.2;
    color("Gray", 0.7)
    for (i = [0 : wago_count - 1]) {
        y_off = i * (wago_w + wago_spacing + 2 * holder_wall);
        translate([wago_x + holder_wall, wago_y + y_off + holder_wall, tray_floor + holder_wall])
            cube([wago_l, wago_w, wago_h]);
    }
}

module dummy_imu() {
    color("Purple", 0.7)
    translate([imu_x, imu_y, tray_floor + imu_standoff])
        cube([imu_l, imu_w, imu_h]);
}

module assembly() {
    electronics_tray();
    dummy_esp32();
    dummy_l298n();
    dummy_lm2596();
    dummy_battery();
    dummy_wago();
    dummy_imu();
}

// =====================================================================
// Render Selected Part
// =====================================================================

if (part == "tray") electronics_tray();
else if (part == "assembly") assembly();
