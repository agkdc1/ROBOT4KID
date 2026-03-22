// Train Desktop Command Station
// Kid-friendly control station for Shinkansen N700 Plarail train
// Components: RPi4, 7" display, PS2 thumbstick, 100mm slide pot,
//             4x Sanwa 24mm buttons, USB encoder, MCP3008 ADC,
//             Anker PowerCore Slim 10000, iUniker USB-C power switch
//
// Split: front panel (display + controls) / rear base (electronics)
// Each piece fits Bambu A1 Mini 180x180x180mm build volume
//
// Part selector via CLI: -D 'part="front"' / "rear" / "assembly"

use <../libs/common.scad>
use <../libs/m3_hardware.scad>

// =====================================================================
// Part Selector
// =====================================================================
part = "assembly";  // "front" | "rear" | "assembly"

$fn = 64;

// =====================================================================
// Structural Constants
// =====================================================================
WALL        = 3.0;      // Extra sturdy for desk use
FLOOR       = 2.5;      // Bottom thickness
FILLET      = 1.5;      // External corner fillets
TOL         = 0.2;      // Print tolerance
CLEARANCE   = 0.4;      // Drop-in clearance

// =====================================================================
// Component Dimensions (EXACT from spec)
// =====================================================================

// RPi 4B: 85x56x17mm board + 5mm heatsink = 22mm total
RPI_L        = 85;
RPI_W        = 56;
RPI_H        = 17;
RPI_HEATSINK = 5;       // Heatsink above board
RPI_AIRFLOW  = 10;      // Airflow gap above heatsink
RPI_MOUNT_X  = 58;      // M2.5 hole spacing X
RPI_MOUNT_Y  = 49;      // M2.5 hole spacing Y

// 7" RPi Touch Display: 194x110x20mm
DISP_W       = 194;
DISP_H       = 110;
DISP_D       = 20;
DISP_TILT    = 20;      // Tilt angle (degrees)
DISP_MOUNT_X = 180;     // M2.5 hole spacing X
DISP_MOUNT_Y = 96;      // M2.5 hole spacing Y
DISP_BEZEL   = 5;       // Frame bezel width

// PS2 Thumbstick Module: 34x26x32mm (same as tank)
JOY_L        = 34;
JOY_W        = 26;
JOY_H        = 32;      // Total including stick travel
JOY_PCB_H    = 10;      // PCB + pots height
JOY_STICK_DIA = 15;     // Stick diameter

// 100mm Slide Potentiometer (Bourns-style): 128x18x16mm
SLIDER_L     = 128;     // Length (travel direction, mounted vertical)
SLIDER_W     = 18;      // Width
SLIDER_H     = 16;      // Height/depth
SLIDER_SLOT_W = 4;      // Knob slot width
SLIDER_KNOB_H = 12;     // Knob protrusion above panel

// Sanwa 24mm Snap-in Buttons
BTN_DIA      = 24;      // Mounting hole diameter
BTN_SPACING  = 30;      // Center-to-center spacing
BTN_DEPTH    = 20;      // Depth below panel

// SJ@JX 822B USB Encoder: 95x35x10mm
ENCODER_L    = 95;
ENCODER_W    = 35;
ENCODER_H    = 10;

// MCP3008 ADC Breakout: 40x20x8mm
ADC_L        = 40;
ADC_W        = 20;
ADC_H        = 8;

// Anker PowerCore Slim 10000: 149x68x14mm
ANKER_L      = 149;
ANKER_W      = 68;
ANKER_H      = 14;

// iUniker USB-C Power Switch housing: 80x40x20mm
SWITCH_L     = 80;
SWITCH_W     = 40;
SWITCH_H     = 20;

// =====================================================================
// Console Overall Dimensions
// =====================================================================
// Width: driven by display (194mm) + 2x wall + margin
CONSOLE_W    = 220;
// Depth: front controls (~55mm) + display base (~30mm) + RPi area (~60mm)
CONSOLE_D    = 160;
// Height: base layer (~20mm) + control panel (~35mm) + display support
CONSOLE_BASE_H  = 22;   // Base layer (power bank + encoder + ADC)
CONSOLE_PANEL_H = 40;   // Control panel height above base
CONSOLE_H    = CONSOLE_BASE_H + CONSOLE_PANEL_H;  // 62mm total (without display)

// Display backrest height (at rear wall, supports tilted display)
DISP_BACK_H  = CONSOLE_H + DISP_H * sin(DISP_TILT);  // ~99.6mm

// Split line: front/rear boundary (Y coordinate)
SPLIT_Y      = 85;      // Controls in front, electronics in rear

// =====================================================================
// Layout Positions (origin = front-left-bottom of console)
// =====================================================================

// --- Bottom layer (Z = FLOOR) ---

// Anker power bank: centered in rear base, on floor
anker_x = (CONSOLE_W - ANKER_L) / 2;
anker_y = SPLIT_Y + (CONSOLE_D - SPLIT_Y - ANKER_W) / 2;
anker_z = FLOOR;

// USB Encoder: front-left of base layer
encoder_x = WALL + 2;
encoder_y = WALL + 2;
encoder_z = FLOOR;

// MCP3008 ADC: front-right of base layer, near throttle
adc_x = CONSOLE_W - WALL - ADC_L - 5;
adc_y = WALL + 2;
adc_z = FLOOR;

// iUniker power switch: right side slot
switch_x = CONSOLE_W - WALL - SWITCH_L;
switch_y = SPLIT_Y + 5;
switch_z = FLOOR;

// --- Control panel (Z = CONSOLE_BASE_H) ---

// PS2 Joystick: left panel
joy_x = WALL + 8;
joy_y = 10;
joy_z = CONSOLE_BASE_H;

// Button panel: center, 2x2 grid
btn_center_x = CONSOLE_W / 2;
btn_center_y = 30;
btn_z = CONSOLE_BASE_H;

// Slide potentiometer: right panel (vertical orientation)
slider_x = CONSOLE_W - WALL - 25;
slider_y = 10;
slider_z = CONSOLE_BASE_H;

// --- Display area (rear, tilted) ---

// Display: centered horizontally, at rear
disp_x = (CONSOLE_W - DISP_W) / 2;
disp_y = SPLIT_Y + 5;
disp_z = CONSOLE_H;

// RPi4: behind/below display, rotated 90deg so USB/Ethernet face rear wall
rpi_x = (CONSOLE_W - RPI_W) / 2;
rpi_y = CONSOLE_D - WALL - RPI_L - 2;
rpi_z = CONSOLE_BASE_H + 5;  // Standoff base height

// =====================================================================
// M2.5 Standoff Module (local, from m3_hardware.scad dimensions)
// =====================================================================
module m25_standoff_local(height=5, outer_dia=5.5) {
    difference() {
        cylinder(h=height, d=outer_dia);
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=M25_HOLE_DIA);
    }
}

// =====================================================================
// Module: display_mount()
// 20-degree tilted frame for 7" RPi touch display
// =====================================================================
module display_mount() {
    translate([disp_x, disp_y, disp_z]) {
        rotate([-DISP_TILT, 0, 0]) {
            // Support frame — outer border with viewing window
            difference() {
                // Outer frame with bezel
                cube([DISP_W + 2 * DISP_BEZEL,
                      DISP_H + 2 * DISP_BEZEL,
                      WALL]);
                // Viewing window (active area)
                translate([DISP_BEZEL + 8, DISP_BEZEL + 8, -0.1])
                    cube([DISP_W - 16, DISP_H - 16, WALL + 0.2]);
            }

            // Rear support lip to hold display in frame
            translate([0, 0, WALL])
            difference() {
                cube([DISP_W + 2 * DISP_BEZEL,
                      DISP_H + 2 * DISP_BEZEL,
                      DISP_D + 2]);
                // Cavity for display body
                translate([DISP_BEZEL - TOL, DISP_BEZEL - TOL, -0.1])
                    cube([DISP_W + 2 * TOL, DISP_H + 2 * TOL, DISP_D + 0.1]);
                // Open back for cables
                translate([DISP_BEZEL + 20, DISP_BEZEL + 20, DISP_D - 5])
                    cube([DISP_W - 40, DISP_H - 40, 10]);
            }

            // M2.5 standoff posts (4 corners of display mount pattern)
            disp_off_x = (DISP_W - DISP_MOUNT_X) / 2 + DISP_BEZEL;
            disp_off_y = (DISP_H - DISP_MOUNT_Y) / 2 + DISP_BEZEL;
            for (dx = [0, DISP_MOUNT_X])
                for (dy = [0, DISP_MOUNT_Y])
                    translate([disp_off_x + dx, disp_off_y + dy, WALL])
                        m25_standoff_local(height=3);
        }

        // Triangular support struts connecting display frame to console top
        // Left strut
        translate([-DISP_BEZEL, 0, 0])
        hull() {
            cube([WALL, 2, 0.1]);
            rotate([-DISP_TILT, 0, 0])
                translate([0, 0, -0.1])
                    cube([WALL, 2, 0.1]);
        }
        // Right strut
        translate([DISP_W + DISP_BEZEL, 0, 0])
        hull() {
            cube([WALL, 2, 0.1]);
            rotate([-DISP_TILT, 0, 0])
                translate([0, 0, -0.1])
                    cube([WALL, 2, 0.1]);
        }
    }

    // Rear backrest wall to support tilted display
    // Extends from console top up to display back edge
    backrest_h = DISP_H * sin(DISP_TILT) + DISP_D * cos(DISP_TILT) + 10;
    translate([disp_x - DISP_BEZEL, CONSOLE_D - WALL, CONSOLE_H - 5])
        cube([DISP_W + 2 * DISP_BEZEL, WALL, backrest_h]);
}

// =====================================================================
// Module: rpi4_mount()
// Behind display, 4x M2.5 standoffs, heatsink + airflow clearance
// =====================================================================
module rpi4_mount() {
    standoff_h = 5;

    translate([rpi_x, rpi_y, rpi_z]) {
        // RPi4 rotated 90deg: 56mm along X, 85mm along Y
        // M2.5 standoffs at 49x58mm pattern (swapped from 58x49)
        off_x = (RPI_W - RPI_MOUNT_Y) / 2;
        off_y = (RPI_L - RPI_MOUNT_X) / 2;
        for (dx = [0, RPI_MOUNT_Y])
            for (dy = [0, RPI_MOUNT_X])
                translate([off_x + dx, off_y + dy, 0])
                    m25_standoff_local(height=standoff_h);

        // Support platform connecting standoffs
        cube([RPI_W, 3, standoff_h]);
        translate([0, RPI_L - 3, 0])
            cube([RPI_W, 3, standoff_h]);
    }
}

// =====================================================================
// Module: rpi4_rear_cutout()
// Cutout in rear wall for Ethernet + 2x USB-A ports
// =====================================================================
module rpi4_rear_cutout() {
    // RPi4 rotated 90deg: USB/Ethernet ports now face +Y (rear wall)
    // Ports span ~45mm along the 56mm short edge (now along X)
    port_w = 50;
    port_h = RPI_H + RPI_HEATSINK + 5;  // Generous clearance
    port_z = rpi_z;

    translate([rpi_x + (RPI_W - port_w) / 2, CONSOLE_D - WALL - 0.1, port_z])
        cube([port_w, WALL + 0.2, port_h]);
}

// =====================================================================
// Module: rpi4_ventilation()
// Vent slots above RPi4 heatsink for airflow
// =====================================================================
module rpi4_ventilation() {
    vent_count = 6;
    vent_w = 3;
    vent_spacing = 7;
    // RPi4 rotated: 56mm along X, 85mm along Y
    start_x = rpi_x + (RPI_W - vent_count * vent_spacing) / 2;

    // Top surface vents
    for (i = [0 : vent_count - 1])
        translate([start_x + i * vent_spacing, rpi_y + 5, CONSOLE_H - WALL - 0.1])
            cube([vent_w, RPI_L - 10, WALL + 0.2]);

    // Rear wall vents for cross-flow
    for (i = [0 : vent_count - 1])
        translate([start_x + i * vent_spacing, CONSOLE_D - WALL - 0.1, rpi_z + 5])
            cube([vent_w, WALL + 0.2, RPI_H + 5]);
}

// =====================================================================
// Module: joystick_mount()
// Left panel — PS2 thumbstick pokes through angled surface
// =====================================================================
module joystick_mount() {
    translate([joy_x, joy_y, joy_z]) {
        // Raised angled platform for joystick
        panel_w = JOY_L + 16;
        panel_d = JOY_W + 14;
        panel_angle = 15;  // Slight tilt toward operator

        // Platform base
        difference() {
            // Angled panel
            hull() {
                cube([panel_w, panel_d, WALL]);
                translate([0, 0, 12])
                    cube([panel_w, 3, WALL]);
            }

            // Joystick stick hole (centered)
            translate([panel_w / 2, panel_d / 2, -0.1])
                cylinder(h=20, d=JOY_STICK_DIA + 3);
        }

        // Side cradle walls for PCB
        cradle_h = JOY_PCB_H + 3;
        cradle_wall = 2;
        // Left wall
        translate([5, 5, -cradle_h])
            cube([cradle_wall, JOY_W + TOL, cradle_h]);
        // Right wall
        translate([5 + cradle_wall + JOY_L + CLEARANCE, 5, -cradle_h])
            cube([cradle_wall, JOY_W + TOL, cradle_h]);
        // Back wall
        translate([5, 5 + JOY_W + CLEARANCE, -cradle_h])
            cube([JOY_L + 2 * cradle_wall + CLEARANCE, cradle_wall, cradle_h]);

        // Shelf for PCB to rest on
        translate([5, 5, -cradle_h])
            cube([JOY_L + 2 * cradle_wall + CLEARANCE, JOY_W + CLEARANCE + cradle_wall, 2]);
    }
}

// =====================================================================
// Module: joystick_cutout()
// Hole for joystick stick through panel
// =====================================================================
module joystick_cutout() {
    translate([joy_x + (JOY_L + 16) / 2, joy_y + (JOY_W + 14) / 2, joy_z - 1])
        cylinder(h=20, d=JOY_STICK_DIA + 3);
}

// =====================================================================
// Module: throttle_slot()
// Right panel — 100mm slide potentiometer in vertical slot
// =====================================================================
module throttle_slot() {
    translate([slider_x, slider_y, slider_z]) {
        // Vertical mounting frame for slider
        frame_w = SLIDER_W + 12;
        frame_h = SLIDER_L + 10;  // Vertical travel direction

        // Mounting frame — left wall, right wall, front face, floor, ceiling
        // Back face is OPEN for slider insertion and wiring access
        difference() {
            union() {
                // Front face panel
                cube([frame_w, WALL, frame_h + 3]);

                // Left side wall
                cube([WALL, WALL + SLIDER_H + 2, frame_h + 3]);

                // Right side wall
                translate([frame_w - WALL, 0, 0])
                    cube([WALL, WALL + SLIDER_H + 2, frame_h + 3]);

                // Floor
                cube([frame_w, WALL + SLIDER_H + 2, 5]);

                // Ceiling
                translate([0, 0, frame_h])
                    cube([frame_w, WALL + SLIDER_H + 2, 3]);
            }

            // Slider body cavity (inside the U-channel)
            translate([(frame_w - SLIDER_W - CLEARANCE) / 2,
                       WALL,
                       5])
                cube([SLIDER_W + CLEARANCE,
                      SLIDER_H + CLEARANCE + 1,
                      SLIDER_L + CLEARANCE]);

            // Knob slot (through front face) — long vertical slot
            translate([(frame_w - SLIDER_SLOT_W) / 2,
                       -0.1,
                       5 + 5])
                cube([SLIDER_SLOT_W + 2,
                      WALL + 0.2,
                      SLIDER_L - 10]);
        }

        // Retaining clips at top and bottom (inward lips)
        clip_w = 8;
        clip_depth = 1.5;
        for (z_off = [7, frame_h - 5])
            translate([(frame_w - clip_w) / 2, WALL + SLIDER_H + CLEARANCE, z_off])
                cube([clip_w, clip_depth, 3]);
    }
}

// =====================================================================
// Module: button_panel()
// Center front — 4x Sanwa 24mm snap-in button holes in 2x2 grid
// =====================================================================
module button_panel() {
    // 2x2 grid centered at btn_center_x, btn_center_y
    translate([btn_center_x, btn_center_y, btn_z]) {
        // Raised panel surface
        panel_w = BTN_SPACING + BTN_DIA + 16;
        panel_d = BTN_SPACING + BTN_DIA + 16;

        difference() {
            // Panel body
            translate([-panel_w / 2, -panel_d / 2, 0])
                rounded_cube([panel_w, panel_d, WALL + 2], r=FILLET);

            // 4x button holes (2x2 grid)
            for (col = [-0.5, 0.5])
                for (row = [-0.5, 0.5])
                    translate([col * BTN_SPACING, row * BTN_SPACING, -0.1])
                        cylinder(h=WALL + 2 + 0.2, d=BTN_DIA + TOL);
        }
    }
}

// =====================================================================
// Module: button_cutouts()
// Subtracted from shell — 4x holes for snap-in buttons
// =====================================================================
module button_cutouts() {
    for (col = [-0.5, 0.5])
        for (row = [-0.5, 0.5])
            translate([btn_center_x + col * BTN_SPACING,
                       btn_center_y + row * BTN_SPACING,
                       btn_z - 0.1])
                cylinder(h=WALL + 5, d=BTN_DIA + TOL);
}

// =====================================================================
// Module: encoder_bay()
// Under console — SJ@JX 822B USB Encoder
// =====================================================================
module encoder_bay() {
    translate([encoder_x, encoder_y, encoder_z]) {
        // Rail mount cradle
        rail_w = 2.5;
        inner_l = ENCODER_L + CLEARANCE;
        inner_w = ENCODER_W + CLEARANCE;

        // Base
        cube([inner_l + 2 * rail_w, inner_w + 2 * rail_w, 1.5]);
        // Side rails
        cube([inner_l + 2 * rail_w, rail_w, ENCODER_H + 2]);
        translate([0, rail_w + inner_w, 0])
            cube([inner_l + 2 * rail_w, rail_w, ENCODER_H + 2]);
        // Back stop
        cube([rail_w, inner_w + 2 * rail_w, ENCODER_H + 2]);
    }
}

// =====================================================================
// Module: adc_mount()
// Near throttle — MCP3008 on M2.5 standoffs
// =====================================================================
module adc_mount() {
    standoff_h = 4;
    translate([adc_x, adc_y, adc_z]) {
        // 2x M2.5 standoffs along center length
        mount_spacing = 32;  // MCP3008 typical hole spacing
        off_x = (ADC_L - mount_spacing) / 2;
        center_y = ADC_W / 2;

        for (dx = [0, mount_spacing])
            translate([off_x + dx, center_y, 0])
                m25_standoff_local(height=standoff_h);

        // Support rails
        cube([ADC_L, 2, standoff_h]);
        translate([0, ADC_W - 2, 0])
            cube([ADC_L, 2, standoff_h]);
    }
}

// =====================================================================
// Module: power_bay()
// Anker PowerCore cradle + iUniker switch side slot
// =====================================================================
module power_bay() {
    // --- Anker PowerCore Slim 10000 cradle ---
    translate([anker_x, anker_y, anker_z]) {
        cradle_wall = 2.5;
        inner_l = ANKER_L + CLEARANCE;
        inner_w = ANKER_W + CLEARANCE;
        cradle_h = ANKER_H * 0.7;

        // Cradle walls
        difference() {
            cube([inner_l + 2 * cradle_wall, inner_w + 2 * cradle_wall, cradle_h]);
            translate([cradle_wall, cradle_wall, 2])
                cube([inner_l, inner_w, cradle_h + 1]);
        }

        // Retaining lips at corners
        lip = 2;
        for (x = [0, inner_l + cradle_wall])
            for (y = [0, inner_w + cradle_wall])
                translate([x, y, cradle_h])
                    cube([cradle_wall, cradle_wall, lip]);
    }
}

// =====================================================================
// Module: anker_usbc_cutout()
// Side cutout for Anker USB-C charging port
// =====================================================================
module anker_usbc_cutout() {
    // USB-C port on short end of Anker — expose through side wall
    usbc_w = 14;
    usbc_h = 10;
    translate([anker_x + ANKER_L + 1, anker_y + (ANKER_W - usbc_w) / 2, anker_z])
        cube([WALL + 5, usbc_w, usbc_h]);
}

// =====================================================================
// Module: power_switch_slot()
// Dedicated side-mount slot for iUniker USB-C power switch
// =====================================================================
module power_switch_slot() {
    // Right side of console, accessible slot
    slot_x = CONSOLE_W - WALL - 0.1;
    slot_y = switch_y;
    slot_z = switch_z;

    // Through-wall opening for switch housing
    translate([slot_x, slot_y, slot_z])
        cube([WALL + 0.2, SWITCH_L + CLEARANCE, SWITCH_H + CLEARANCE]);

    // Internal cavity for switch body
    translate([CONSOLE_W - WALL - SWITCH_W - 2, slot_y, slot_z])
        cube([SWITCH_W + 2, SWITCH_L + CLEARANCE, SWITCH_H + CLEARANCE]);
}

// =====================================================================
// Module: cable_guides()
// SPI signal vs power wire separation
// =====================================================================
module cable_guides() {
    guide_wall = 1.5;
    guide_h = 10;

    // --- SPI signal channel (MCP3008 to RPi4 GPIO) ---
    // Runs from ADC area toward rear (RPi4)
    translate([adc_x + ADC_L / 2 - 5, adc_y + ADC_W + 2, FLOOR]) {
        // Left wall
        cube([guide_wall, SPLIT_Y - adc_y - ADC_W, guide_h]);
        // Right wall (10mm channel width)
        translate([10 + guide_wall, 0, 0])
            cube([guide_wall, SPLIT_Y - adc_y - ADC_W, guide_h]);
    }

    // --- Power wire channel (Anker to encoder, switch) ---
    // Runs along left side of base
    translate([WALL + 2, WALL + ENCODER_W + 8, FLOOR]) {
        cube([guide_wall, SPLIT_Y - WALL - ENCODER_W - 10, guide_h]);
        translate([15 + guide_wall, 0, 0])
            cube([guide_wall, SPLIT_Y - WALL - ENCODER_W - 10, guide_h]);
    }

    // --- Divider wall between SPI and power zones ---
    translate([CONSOLE_W / 2 - guide_wall / 2, WALL + 2, FLOOR])
        cube([guide_wall, SPLIT_Y - WALL - 5, guide_h + 2]);
}

// =====================================================================
// Module: console_shell()
// Complete outer shell with filleted corners
// =====================================================================
module console_shell() {
    difference() {
        union() {
            // Main box body
            rounded_cube([CONSOLE_W, CONSOLE_D, CONSOLE_H], r=FILLET);

            // Display backrest (raised rear wall)
            translate([0, CONSOLE_D - WALL - 3, 0])
                rounded_cube([CONSOLE_W, WALL + 3, DISP_BACK_H], r=FILLET);
        }

        // Hollow interior
        translate([WALL, WALL, FLOOR])
            cube([CONSOLE_W - 2 * WALL,
                  CONSOLE_D - 2 * WALL,
                  CONSOLE_H + DISP_BACK_H]);  // Open top

        // Display backrest interior
        translate([WALL, CONSOLE_D - WALL - 3 + WALL, FLOOR])
            cube([CONSOLE_W - 2 * WALL,
                  3,
                  DISP_BACK_H]);
    }
}

// =====================================================================
// Module: rubber_feet()
// 4x recesses on bottom for adhesive rubber feet
// =====================================================================
module rubber_feet() {
    foot_dia = 10;
    foot_depth = 1.5;
    inset = 15;

    positions = [
        [inset,                 inset],
        [CONSOLE_W - inset,     inset],
        [inset,                 CONSOLE_D - inset],
        [CONSOLE_W - inset,     CONSOLE_D - inset]
    ];

    for (p = positions)
        translate([p[0], p[1], -0.1])
            cylinder(h=foot_depth + 0.1, d=foot_dia);
}

// =====================================================================
// Module: split_keys()
// Alignment keys/sockets along the split line (Y = SPLIT_Y)
// =====================================================================
KEY_SIZE   = 5;
KEY_HEIGHT = 4;

module split_keys_male() {
    // Male keys on front piece, facing rear
    for (x = [CONSOLE_W * 0.25, CONSOLE_W * 0.75])
        for (z = [CONSOLE_H * 0.33, CONSOLE_H * 0.66])
            translate([x, SPLIT_Y, z])
                rotate([-90, 0, 0])
                    split_key(size=KEY_SIZE, height=KEY_HEIGHT);
}

module split_keys_female() {
    // Female sockets on rear piece, facing front
    for (x = [CONSOLE_W * 0.25, CONSOLE_W * 0.75])
        for (z = [CONSOLE_H * 0.33, CONSOLE_H * 0.66])
            translate([x, SPLIT_Y, z])
                rotate([-90, 0, 0])
                    split_socket(size=KEY_SIZE, height=KEY_HEIGHT);
}

// M3 bolt holes along split seam
module split_bolts() {
    bolt_depth = 12;
    for (x = [CONSOLE_W * 0.2, CONSOLE_W * 0.5, CONSOLE_W * 0.8])
        translate([x, SPLIT_Y, CONSOLE_H * 0.5])
            rotate([-90, 0, 0])
                translate([0, 0, -bolt_depth / 2])
                    m3_hole(depth=bolt_depth);
}

// =====================================================================
// Module: console_front()
// Front piece: display frame area + control panel + front base
// Printable part (fits 180x180x180mm on its back)
// =====================================================================
module console_front() {
    difference() {
        union() {
            // Front portion of shell
            intersection() {
                console_shell();
                cube([CONSOLE_W + 10, SPLIT_Y, DISP_BACK_H + 10]);
            }

            // Male alignment keys
            split_keys_male();

            // Joystick mount
            joystick_mount();

            // Button panel
            button_panel();

            // Throttle slot frame
            throttle_slot();

            // Encoder bay
            encoder_bay();

            // ADC mount
            adc_mount();

            // Cable guides (front portion)
            intersection() {
                cable_guides();
                cube([CONSOLE_W + 10, SPLIT_Y, CONSOLE_H + 10]);
            }
        }

        // Joystick hole through panel
        joystick_cutout();

        // Button holes
        button_cutouts();

        // Rubber feet (front portion)
        intersection() {
            rubber_feet();
            cube([CONSOLE_W + 10, SPLIT_Y, CONSOLE_H + 10]);
        }

        // Split bolt holes
        split_bolts();
    }
}

// =====================================================================
// Module: console_rear()
// Rear piece: RPi4 area, display support, power bay, switch slot
// Printable part (fits 180x180x180mm)
// =====================================================================
module console_rear() {
    difference() {
        union() {
            // Rear portion of shell (including display backrest)
            intersection() {
                console_shell();
                translate([0, SPLIT_Y, 0])
                    cube([CONSOLE_W + 10,
                          CONSOLE_D - SPLIT_Y + 10,
                          DISP_BACK_H + 10]);
            }

            // RPi4 mount standoffs
            rpi4_mount();

            // Power bay cradle
            intersection() {
                power_bay();
                translate([0, SPLIT_Y, 0])
                    cube([CONSOLE_W + 10, CONSOLE_D, CONSOLE_H + 10]);
            }

            // Display mount frame and backrest
            display_mount();

            // Cable guides (rear portion)
            intersection() {
                cable_guides();
                translate([0, SPLIT_Y, 0])
                    cube([CONSOLE_W + 10, CONSOLE_D, CONSOLE_H + 10]);
            }
        }

        // Female alignment sockets
        split_keys_female();

        // RPi4 Ethernet + USB rear cutout
        rpi4_rear_cutout();

        // RPi4 ventilation slots
        rpi4_ventilation();

        // Anker USB-C port cutout
        anker_usbc_cutout();

        // iUniker power switch side slot
        power_switch_slot();

        // Rubber feet (rear portion)
        intersection() {
            rubber_feet();
            translate([0, SPLIT_Y, 0])
                cube([CONSOLE_W + 10, CONSOLE_D, CONSOLE_H + 10]);
        }

        // Split bolt holes
        split_bolts();
    }
}

// =====================================================================
// Module: show_components()
// Transparent dummy volumes for assembly visualization
// =====================================================================
module show_components() {
    // 7" Display (tilted)
    color("DarkSlateGray", 0.3)
    translate([disp_x, disp_y, disp_z])
    rotate([-DISP_TILT, 0, 0])
        cube([DISP_W, DISP_H, DISP_D]);

    // RPi 4B (rotated 90deg: 56mm along X, 85mm along Y)
    color("Green", 0.35)
    translate([rpi_x, rpi_y, rpi_z + 5])
        cube([RPI_W, RPI_L, RPI_H]);

    // RPi heatsink
    color("Silver", 0.3)
    translate([rpi_x + 8, rpi_y + 20, rpi_z + 5 + RPI_H])
        cube([30, 40, RPI_HEATSINK]);

    // PS2 Joystick
    color("Blue", 0.35)
    translate([joy_x + 8, joy_y + 7, joy_z - JOY_PCB_H]) {
        cube([JOY_L, JOY_W, JOY_PCB_H]);
        translate([JOY_L / 2, JOY_W / 2, JOY_PCB_H])
            cylinder(h=JOY_H - JOY_PCB_H, d=JOY_STICK_DIA);
    }

    // Slide Potentiometer (vertical)
    color("DarkRed", 0.35)
    translate([slider_x + (SLIDER_W + 12 - SLIDER_W) / 2,
               slider_y + WALL,
               slider_z + 5])
        cube([SLIDER_W, SLIDER_H, SLIDER_L]);

    // 4x Sanwa Buttons (shown as cylinders)
    color("Red", 0.4)
    for (col = [-0.5, 0.5])
        for (row = [-0.5, 0.5])
            translate([btn_center_x + col * BTN_SPACING,
                       btn_center_y + row * BTN_SPACING,
                       btn_z])
                cylinder(h=8, d=BTN_DIA);

    // USB Encoder
    color("Purple", 0.3)
    translate([encoder_x + 2.5, encoder_y + 2.5, encoder_z + 1.5])
        cube([ENCODER_L, ENCODER_W, ENCODER_H]);

    // MCP3008 ADC
    color("Orange", 0.35)
    translate([adc_x, adc_y, adc_z + 4])
        cube([ADC_L, ADC_W, ADC_H]);

    // Anker PowerCore Slim 10000
    color("DimGray", 0.3)
    translate([anker_x + 2.5, anker_y + 2.5, anker_z + 2])
        cube([ANKER_L, ANKER_W, ANKER_H]);

    // iUniker Power Switch (side slot)
    color("Black", 0.3)
    translate([CONSOLE_W - WALL - SWITCH_W - 1, switch_y, switch_z])
        cube([SWITCH_W, SWITCH_L, SWITCH_H]);
}

// =====================================================================
// Module: console_assembly()
// Full assembly visualization (both pieces joined)
// =====================================================================
module console_assembly() {
    color("LightSteelBlue", 0.6)
        console_front();

    color("SteelBlue", 0.6)
        console_rear();

    show_components();
}

// =====================================================================
// Render Selected Part
// =====================================================================
if (part == "front")    console_front();
else if (part == "rear")  console_rear();
else if (part == "assembly") console_assembly();
