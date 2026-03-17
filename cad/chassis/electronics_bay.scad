// M1A1 Abrams — Electronics Bay / Internal Tray
// Redesigned for ESP32-CAM + MB programmer stack + L9110S motor driver
// Removable tray that sits on hull floor, houses all electronics
// Fits within hull interior: ~134x134x50mm (after 2.5mm hull walls)

use <../libs/common.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

// --- Part Selector ---
// Set via CLI: -D 'part="tray"'
part = "assembly";  // "tray" | "assembly"

// --- Tray Dimensions ---
tray_length   = 130;           // Fits hull interior with clearance
tray_width    = 130;           // Fits hull interior with clearance
tray_height   = 40;            // Vertical clearance for components
tray_wall     = 2.5;           // Structural wall thickness
tray_floor    = 2.0;           // Floor thickness
tray_corner_r = 2;             // Corner radius

// --- Component Dimensions ---
// ESP32-CAM + MB Programmer Stack
cam_l         = 40;
cam_w         = 27;
cam_h         = 25;            // CAM 12mm + headers 8.5mm + MB 4mm
cam_standoff  = 3;             // M2.5 standoff height under MB board
cam_antenna_h = 10;            // Top 10mm must be clear (antenna zone)

// L9110S Motor Driver
l9110s_l      = 29;
l9110s_w      = 23;
l9110s_h      = 15;
l9110s_standoff = 3;           // M2.5 standoff height

// 18650 Battery Holder (2S)
batt_l        = 77;
batt_w        = 41;
batt_h        = 22;
batt_lip      = 3;            // Retaining lip height
batt_lip_t    = 1.2;          // Lip thickness

// WAGO 221-413 Connectors (3-way)
wago_l        = 20;
wago_w        = 13;
wago_h        = 16;
wago_count    = 3;
wago_spacing  = 2;

// MPU-6050 IMU (at geometric center for accurate readings)
mpu_l         = 21;
mpu_w         = 16;
mpu_h         = 3;
mpu_mount_x   = 15.2;         // M2.5 hole spacing X
mpu_mount_y   = 12.5;         // M2.5 hole spacing Y
mpu_clip_h    = 4;             // Snap-fit clip height (wraps over board)
mpu_clip_t    = 1.2;           // Clip wall thickness
mpu_clip_gap  = 0.3;           // Clearance around board

// --- USB Access Port ---
usb_port_w    = 8;            // Micro-USB opening width
usb_port_h    = 4;            // Micro-USB opening height

// --- Wire Channel Dimensions ---
signal_ch_w   = 5;            // Signal wire channel width (GPIO → L9110S)
power_ch_w    = 8;            // Power wire channel width (battery → WAGO → L9110S)
ch_depth      = 8;            // Channel wall height
ch_rib_t      = 1.2;          // Channel wall thickness

// --- Z-shape Cable Relief ---
zigzag_w      = 3;            // Zigzag channel width
zigzag_depth  = 4;            // How deep into wall
zigzag_step   = 6;            // Vertical step of each zig

// --- Slip-Ring Void ---
slip_ring_dia = 22;

// --- Ventilation Slots ---
vent_count    = 4;
vent_length   = 12;
vent_width    = 3;
vent_spacing  = 5;

// --- Component Positions (from tray origin, bottom-left corner) ---
// All positions are [x, y] on tray floor (z = tray_floor)

// ESP32-CAM + MB — front-left of tray (easy USB access from front wall)
cam_x         = tray_wall + 3;
cam_y         = tray_wall + 3;

// L9110S — next to ESP32-CAM, screw terminals face outward (toward Y-max wall)
l9110s_x      = cam_x;
l9110s_y      = cam_y + cam_w + 5;

// Battery holder — opposite end of tray
batt_x        = tray_length - tray_wall - batt_l - 2;
batt_y        = (tray_width - batt_w) / 2;

// WAGO connectors — near battery for short power runs
wago_x        = batt_x - wago_l - 8;
wago_y        = batt_y;

// --- Mounting Holes (4 corners, M3 to hull floor) ---
mount_inset   = 8;             // From tray edge

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

        // USB access port — front wall (X=0), aligned with MB programmer Micro-USB
        // USB port is roughly centered on the short side of the CAM+MB stack
        usb_port_z = tray_floor + cam_standoff + 2;  // MB board USB height
        usb_port_y = cam_y + cam_w / 2 - usb_port_w / 2;
        translate([-0.05, usb_port_y, usb_port_z])
            cube([tray_wall + 0.1, usb_port_w, usb_port_h]);

        // Antenna clearance — remove wall material above top 10mm of ESP32-CAM
        // The antenna is at the top of the board, near Y=0 edge
        antenna_z = tray_floor + cam_standoff + cam_h - cam_antenna_h;
        translate([-0.05, cam_y - 1, antenna_z])
            cube([tray_wall + 0.1, cam_w + 5, cam_antenna_h + 5]);
    }
}

module m3_mount_bosses() {
    // 4 corner mounting bosses with M3 through-holes
    boss_d = 7;
    positions = [
        [mount_inset,                mount_inset],
        [tray_length - mount_inset,  mount_inset],
        [mount_inset,                tray_width - mount_inset],
        [tray_length - mount_inset,  tray_width - mount_inset]
    ];
    for (p = positions) {
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

module cam_standoffs() {
    // 2x M2.5 standoffs for ESP32-CAM MB programmer mounting holes
    // MB programmer has 2 mounting holes along the long axis
    inset_x = 4;
    mid_y   = cam_w / 2;
    positions = [
        [cam_x + inset_x,            cam_y + mid_y],
        [cam_x + cam_l - inset_x,    cam_y + mid_y]
    ];
    for (p = positions) {
        translate([p[0], p[1], tray_floor])
            m25_standoff(height=cam_standoff, outer_dia=5.5);
    }
}

module l9110s_standoffs() {
    // 2x M2.5 standoffs for L9110S motor driver
    inset_x = 3;
    mid_y   = l9110s_w / 2;
    positions = [
        [l9110s_x + inset_x,            l9110s_y + mid_y],
        [l9110s_x + l9110s_l - inset_x, l9110s_y + mid_y]
    ];
    for (p = positions) {
        translate([p[0], p[1], tray_floor])
            m25_standoff(height=l9110s_standoff, outer_dia=5.5);
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
    // Snap-in brackets for WAGO 221-413 lever connectors
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

// --- MPU-6050 IMU Mount (geometric center, snap-fit clips) ---
module mpu6050_mount() {
    // Position at geometric center of tray for accurate IMU readings
    cx = tray_length / 2;
    cy = tray_width / 2;

    translate([cx - mpu_l/2, cy - mpu_w/2, tray_floor]) {
        // Base platform (raised 1mm for clearance)
        cube([mpu_l, mpu_w, 1]);

        // 4 snap-fit clips (one on each edge, wrap over the board)
        // Front clip
        translate([mpu_l/2 - 3, -mpu_clip_t, 0])
            snap_clip();
        // Rear clip
        translate([mpu_l/2 - 3, mpu_w, 0])
            snap_clip();
        // Left clip
        translate([-mpu_clip_t, mpu_w/2 - 3, 0])
            rotate([0, 0, 90]) snap_clip();
        // Right clip
        translate([mpu_l, mpu_w/2 - 3, 0])
            rotate([0, 0, 90]) snap_clip();
    }
}

module snap_clip() {
    // L-shaped snap clip: vertical wall + inward lip
    clip_w = 6;
    difference() {
        union() {
            // Vertical wall
            cube([clip_w, mpu_clip_t, mpu_h + mpu_clip_h]);
            // Inward lip (snaps over board edge)
            translate([0, 0, mpu_h + mpu_clip_h - 1])
                cube([clip_w, mpu_clip_t + 1.5, 1]);
        }
        // Chamfer on lip for easy snap-in
        translate([0, mpu_clip_t + 1.5, mpu_h + mpu_clip_h])
            rotate([45, 0, 0])
                cube([clip_w + 0.1, 2, 2]);
    }
}

// --- I2C Wire Conduit (separate from motor power lines) ---
module i2c_conduit() {
    // Shielded channel from MPU-6050 center to ESP32-CAM GPIO 14/15
    // Runs along the tray floor, separated from power channels
    conduit_w = 4;     // Narrow — only 4 wires (VCC, GND, SCL, SDA)
    conduit_h = 5;
    cx = tray_length / 2;
    cy = tray_width / 2;

    // Route from center toward ESP32-CAM position
    translate([cam_x + cam_l, cy - conduit_w/2, tray_floor])
        cube([cx - cam_x - cam_l, conduit_w, conduit_h]);

    // Side walls for channel
    for (y_off = [cy - conduit_w/2 - ch_rib_t, cy + conduit_w/2]) {
        translate([cam_x + cam_l, y_off, tray_floor])
            cube([cx - cam_x - cam_l, ch_rib_t, conduit_h]);
    }
}

module zigzag_cable_relief() {
    // Z-shape cable relief brackets along tray walls
    // Dupont connectors thread through zigzag channels to prevent pull-out
    relief_h = 20;     // Total height of relief section
    num_zigs = 3;

    // Relief channels along the front wall (X=tray_wall, inner face)
    // Two relief points: near ESP32-CAM and near L9110S
    relief_positions = [
        [tray_wall, cam_y + cam_w + 1],       // Between CAM and L9110S
        [tray_wall, l9110s_y + l9110s_w + 1],  // After L9110S
    ];

    for (pos = relief_positions) {
        translate([pos[0], pos[1], tray_floor]) {
            for (i = [0 : num_zigs - 1]) {
                z_off = i * zigzag_step;
                // Alternating left-right notches create Z path
                x_off = (i % 2 == 0) ? 0 : zigzag_w;
                translate([x_off, 0, z_off])
                    cube([zigzag_w, zigzag_w, zigzag_step]);
            }
        }
    }

    // Relief channels along the side wall (Y=tray_width-tray_wall)
    // Near the power wire exit to motors
    side_positions = [
        [cam_x + cam_l + 5, tray_width - tray_wall - zigzag_w],
        [l9110s_x + l9110s_l + 5, tray_width - tray_wall - zigzag_w],
    ];

    for (pos = side_positions) {
        translate([pos[0], pos[1], tray_floor]) {
            for (i = [0 : num_zigs - 1]) {
                z_off = i * zigzag_step;
                y_off = (i % 2 == 0) ? 0 : zigzag_w;
                translate([0, y_off, z_off])
                    cube([zigzag_w, zigzag_w, zigzag_step]);
            }
        }
    }
}

module wire_channel_walls() {
    // Raised rib walls forming separate signal and power channels

    translate([0, 0, tray_floor]) {
        // === Signal channel (5mm wide) — along Y-min wall side ===
        // Runs from ESP32-CAM GPIO pins to L9110S logic inputs
        sig_x0 = cam_x + cam_l + 2;
        sig_x1 = l9110s_x + l9110s_l + 2;
        sig_y  = tray_wall + 1;

        // Inner wall
        translate([cam_x, sig_y, 0])
            cube([sig_x1 - cam_x, ch_rib_t, ch_depth]);
        // Outer wall
        translate([cam_x, sig_y + ch_rib_t + signal_ch_w, 0])
            cube([sig_x1 - cam_x, ch_rib_t, ch_depth]);

        // === Power channel (8mm wide) — along Y-max wall side ===
        // Runs from battery → WAGO → L9110S VCC
        pwr_y = tray_width - tray_wall - power_ch_w - ch_rib_t - 1;

        // Inner wall
        translate([wago_x, pwr_y, 0])
            cube([batt_x + batt_l - wago_x, ch_rib_t, ch_depth]);
        // Outer wall
        translate([wago_x, pwr_y + ch_rib_t + power_ch_w, 0])
            cube([batt_x + batt_l - wago_x, ch_rib_t, ch_depth]);

        // Cross-channel: WAGO to L9110S power (perpendicular run)
        translate([wago_x + wago_l / 2 - ch_rib_t / 2, l9110s_y + l9110s_w + 2, 0])
            cube([ch_rib_t, pwr_y - l9110s_y - l9110s_w - 2, ch_depth]);
        translate([wago_x + wago_l / 2 + power_ch_w, l9110s_y + l9110s_w + 2, 0])
            cube([ch_rib_t, pwr_y - l9110s_y - l9110s_w - 2, ch_depth]);
    }
}

module slip_ring_void() {
    // 22mm void at center for slip-ring / turret wiring pass-through
    translate([tray_length / 2, tray_width / 2, -0.05])
        cylinder(h=tray_floor + 0.1, d=slip_ring_dia + 1);
}

module ventilation_slots() {
    // Vertical slots in tray walls for airflow
    // Fewer needed since L9110S runs cooler than L298N
    for (i = [0 : vent_count - 1]) {
        // Side wall slots (Y-max wall)
        translate([l9110s_x + 3 + i * (vent_width + vent_spacing),
                   tray_width - tray_wall - 0.05,
                   tray_floor + 10])
            cube([vent_width, tray_wall + 0.1, vent_length]);
    }
}

module zip_tie_anchors() {
    // Zip-tie pass-through posts at strategic routing points
    positions = [
        // Near ESP32-CAM output
        [cam_x + cam_l + 2,     cam_y + cam_w / 2],
        // Near L9110S output
        [l9110s_x + l9110s_l + 2, l9110s_y + l9110s_w / 2],
        // Near battery holder
        [batt_x - 3,           batt_y + batt_w / 2],
        // Near WAGO area
        [wago_x + wago_l + 3,  wago_y + 5],
    ];

    for (p = positions) {
        translate([p[0], p[1], tray_floor]) {
            for (dx = [-zt_post_w, zt_post_w]) {
                translate([dx, -zt_post_w / 2, 0])
                    cube([zt_post_w, zt_post_w, zt_post_h]);
            }
        }
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
            cam_standoffs();
            l9110s_standoffs();
            battery_cradle();
            wago_holders();
            zigzag_cable_relief();
            zip_tie_anchors();
        }

        // Subtractive features
        m3_mount_holes();
        slip_ring_void();
        ventilation_slots();
    }

    // Wire channel walls are additive ribs on the floor
    wire_channel_walls();
}

// =====================================================================
// Dummy Components (for assembly visualization)
// =====================================================================

module dummy_esp32_cam() {
    // ESP32-CAM + MB programmer stack
    color("DarkGreen", 0.7)
    translate([cam_x, cam_y, tray_floor + cam_standoff])
        cube([cam_l, cam_w, cam_h]);
}

module dummy_l9110s() {
    color("Red", 0.7)
    translate([l9110s_x, l9110s_y, tray_floor + l9110s_standoff])
        cube([l9110s_l, l9110s_w, l9110s_h]);
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

module assembly() {
    electronics_tray();
    mpu6050_mount();
    i2c_conduit();
    dummy_esp32_cam();
    dummy_l9110s();
    dummy_battery();
    dummy_wago();
    // MPU-6050 dummy volume at center
    color("Purple", 0.7)
    translate([tray_length/2 - mpu_l/2, tray_width/2 - mpu_w/2, tray_floor + 1])
        cube([mpu_l, mpu_w, mpu_h]);
}

// =====================================================================
// Render Selected Part
// =====================================================================

if (part == "tray") electronics_tray();
else if (part == "assembly") assembly();
