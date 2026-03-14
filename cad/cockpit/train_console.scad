// Train Console — RPi4 + 7" Touch Display + PS2 Joystick
// Portable control station for train robot
// Split into left and right halves for Bambu A1 Mini build volume
// Overall: ~220 x 140 x 50mm (each half: 110 x 140 x 50mm)

use <../libs/common.scad>
use <../libs/electronics.scad>
use <../libs/mounts.scad>
use <../libs/m3_hardware.scad>
use <../libs/m4_hardware.scad>

// --- Console Dimensions ---
TCONSOLE_WIDTH  = 220;              // Total width (split at 110mm)
TCONSOLE_DEPTH  = 140;              // Front to back
TCONSOLE_HEIGHT = 50;               // Overall height

// --- Display (RPi 7" Touch) ---
// From electronics.scad: RPI_DISPLAY_W=194, RPI_DISPLAY_H=110, RPI_DISPLAY_D=20
display_tilt    = 15;               // Display tilt angle (degrees)
display_bezel   = 5;                // Frame bezel width

// --- RPi4 (mounted behind/below display) ---
// From electronics.scad: RPI4_L=85, RPI4_W=56, RPI4_H=17
rpi_standoff_h  = 5;                // M2.5 standoff height under RPi4

// --- PS2 Joystick ---
// From electronics.scad: PS2_JOY_L=40, PS2_JOY_W=40, PS2_JOY_H=32
joystick_angle  = 20;               // Angled panel tilt (degrees)
joy_panel_w     = 60;               // Joystick panel width
joy_panel_d     = 50;               // Joystick panel depth

// --- MCP3008 ADC ---
// From electronics.scad: MCP3008_L=40, MCP3008_W=20, MCP3008_H=8

// --- Anker PowerCore Slim 10000 ---
// From electronics.scad: ANKER_SLIM_L=149, ANKER_SLIM_W=68, ANKER_SLIM_H=14

// --- Structural ---
wall            = 1.6;              // Wall thickness
half_width      = TCONSOLE_WIDTH / 2;   // 110mm per half (< 180mm build limit)

// --- Split Joint ---
key_size        = 4;
key_height      = 3;
bolt_depth      = 10;

// --- Rubber Feet ---
foot_dia        = 8;
foot_depth      = 2;

// --- Ventilation ---
vent_count      = 6;
vent_w          = 3;
vent_h          = 12;

// --- Cable Management ---
cable_ch_w      = 10;               // Internal cable channel width
cable_ch_h      = 6;                // Internal cable channel depth
ribbon_ch_w     = 18;               // DSI ribbon cable channel width
ribbon_ch_h     = 4;                // DSI ribbon cable channel height

// --- USB-C Pass-Through ---
usbc_w          = 12;               // USB-C port opening width
usbc_h          = 7;                // USB-C port opening height

// --- Part Selector ---
// Set via CLI: -D 'part="left"'
part = "assembly";  // "left" | "right" | "assembly"

$fn = 64;

// =====================================================
// Component Placement (full console coordinate system)
// =====================================================

// Battery bay — centered underneath, long axis along width
batt_x = (TCONSOLE_WIDTH - ANKER_SLIM_L) / 2;   // centered
batt_y = (TCONSOLE_DEPTH - ANKER_SLIM_W) / 2;    // centered in depth
batt_z = wall;                                     // sits on floor

// RPi4 — behind display, centered horizontally
rpi_x  = (TCONSOLE_WIDTH - RPI4_L) / 2;
rpi_y  = TCONSOLE_DEPTH - RPI4_W - wall - 5;     // near back
rpi_z  = batt_z + ANKER_SLIM_H + 2;              // above battery

// Display — top, centered, tilted
disp_x = (TCONSOLE_WIDTH - RPI_DISPLAY_W) / 2;
disp_y = TCONSOLE_DEPTH - RPI_DISPLAY_H - 10;    // near back
disp_z = TCONSOLE_HEIGHT - 5;                     // near top

// Joystick — front center, on angled panel
joy_x  = (TCONSOLE_WIDTH - PS2_JOY_L) / 2;
joy_y  = 15;                                       // near front edge
joy_z  = TCONSOLE_HEIGHT - 8;                      // panel surface

// MCP3008 — next to joystick, right side
mcp_x  = joy_x + PS2_JOY_L + 10;
mcp_y  = joy_y + 5;
mcp_z  = rpi_z;

// =====================================================
// Modules
// =====================================================

module console_base_half() {
    // One half of the outer shell
    difference() {
        rounded_cube([half_width, TCONSOLE_DEPTH, TCONSOLE_HEIGHT], r=3);
        // Hollow interior
        translate([wall, wall, wall])
            cube([half_width - wall, TCONSOLE_DEPTH - 2 * wall, TCONSOLE_HEIGHT]);
    }
}

module display_frame_cutout() {
    // Tilted display frame opening on top surface
    // Full console coordinate system
    translate([disp_x - display_bezel, disp_y - display_bezel, disp_z])
    rotate([-display_tilt, 0, 0]) {
        // Display recess
        cube([RPI_DISPLAY_W + 2 * display_bezel,
              RPI_DISPLAY_H + 2 * display_bezel,
              RPI_DISPLAY_D + 5]);
        // Viewing window through shell
        translate([display_bezel + 5, display_bezel + 5, -wall - 0.1])
            cube([RPI_DISPLAY_W - 10, RPI_DISPLAY_H - 10, wall + 0.2]);
    }
}

module display_mount_standoffs() {
    // M2.5 standoffs for display mounting
    // Full console coordinate system
    translate([disp_x, disp_y, disp_z - rpi_standoff_h])
    rotate([-display_tilt, 0, 0])
        rpi_display_7in_mount(standoff_h=rpi_standoff_h);
}

module rpi4_mount_area() {
    // RPi4 M2.5 standoffs behind display
    translate([rpi_x, rpi_y, rpi_z])
        rpi4_mount(standoff_h=rpi_standoff_h);
}

module rpi4_ventilation() {
    // Vent slots on back wall above RPi4
    slot_spacing = 50 / (vent_count - 1);
    vent_start_x = rpi_x + 10;
    vent_z_start = rpi_z + 3;

    for (i = [0 : vent_count - 1]) {
        translate([vent_start_x + i * slot_spacing, TCONSOLE_DEPTH - wall - 0.1, vent_z_start])
            cube([vent_w, wall + 0.2, vent_h]);
    }
}

module joystick_panel_cutout() {
    // Angled panel area in front for joystick
    // Full console coordinate system
    panel_base_h = 10;  // base height before angle starts

    translate([joy_x - 10, joy_y - 5, TCONSOLE_HEIGHT - 15])
    rotate([-joystick_angle, 0, 0]) {
        // Cutout for joystick stick to poke through
        translate([10 + PS2_JOY_L / 2, 5 + PS2_JOY_W / 2, -wall - 0.1])
            cylinder(h=wall + 5, d=PS2_JOY_STICK_DIA + 4);
    }
}

module joystick_mount_area() {
    // PS2 joystick standoffs on angled panel
    translate([joy_x, joy_y, joy_z - PS2_JOY_PCB_H - 5])
        ps2_joystick_mount(standoff_h=5);
}

module mcp3008_mount_area() {
    // MCP3008 rail mount next to joystick
    translate([mcp_x, mcp_y, mcp_z])
        mcp3008_mount(standoff_h=5);
}

module battery_bay() {
    // Pocket for Anker PowerCore Slim 10000
    // Full console coordinate system
    tol = 0.3;
    translate([batt_x - tol, batt_y - tol, batt_z - 0.1])
        cube([ANKER_SLIM_L + 2 * tol, ANKER_SLIM_W + 2 * tol, ANKER_SLIM_H + tol + 0.1]);

    // Access opening on one short side for USB-C ports
    translate([batt_x + ANKER_SLIM_L - 0.1, batt_y + 10, batt_z])
        cube([wall + 5, ANKER_SLIM_W - 20, ANKER_SLIM_H]);
}

module battery_bay_cradle() {
    // Retaining lips for battery
    lip = 1.5;
    lip_h = 2;
    // Corner lips
    for (x = [batt_x - 0.5, batt_x + ANKER_SLIM_L - lip])
        for (y = [batt_y - 0.5, batt_y + ANKER_SLIM_W - lip])
            translate([x, y, batt_z + ANKER_SLIM_H])
                cube([lip + 0.5, lip + 0.5, lip_h]);
}

module ribbon_cable_channel() {
    // DSI ribbon cable channel from RPi4 to display
    // Full console coordinate system
    translate([TCONSOLE_WIDTH / 2 - ribbon_ch_w / 2, rpi_y + RPI4_W - 5, rpi_z + RPI4_H])
        cube([ribbon_ch_w, 20, disp_z - rpi_z - RPI4_H + 5]);
}

module gpio_cable_channel() {
    // Internal cable routing from RPi4 GPIO to MCP3008 to joystick
    // Full console coordinate system
    // Horizontal channel from RPi4 GPIO area to MCP3008
    translate([rpi_x + RPI4_L - 55, rpi_y - 5, rpi_z - 1])
        cube([cable_ch_w, rpi_y - mcp_y + 15, cable_ch_h]);

    // Vertical channel from MCP3008 down to joystick area
    translate([mcp_x + MCP3008_L / 2 - cable_ch_w / 2, joy_y + PS2_JOY_W, mcp_z - 2])
        cube([cable_ch_w, mcp_y - joy_y - PS2_JOY_W + 10, cable_ch_h]);
}

module usbc_passthrough() {
    // USB-C power pass-through opening on back wall
    translate([TCONSOLE_WIDTH / 2 - usbc_w / 2, TCONSOLE_DEPTH - wall - 0.1, wall + ANKER_SLIM_H / 2 - usbc_h / 2])
        cube([usbc_w, wall + 0.2, usbc_h]);
}

module rubber_feet_recesses() {
    // 4x rubber foot recesses on bottom
    inset = 12;
    positions = [
        [inset,                     inset],
        [TCONSOLE_WIDTH - inset,    inset],
        [inset,                     TCONSOLE_DEPTH - inset],
        [TCONSOLE_WIDTH - inset,    TCONSOLE_DEPTH - inset]
    ];

    for (p = positions)
        translate([p[0], p[1], -0.1])
            cylinder(h=foot_depth + 0.1, d=foot_dia);
}

module side_ventilation() {
    // Vent slots on both side walls for RPi4 airflow
    vent_z_start = rpi_z;
    vent_spacing = (vent_h + 4);

    for (side = [0, 1]) {
        x_pos = side == 0 ? -0.1 : TCONSOLE_WIDTH - wall;
        for (i = [0 : 2]) {
            translate([x_pos, TCONSOLE_DEPTH / 2 - 15 + i * 12, vent_z_start + 2])
                cube([wall + 0.2, vent_w, vent_h]);
        }
    }
}

// =====================================================
// Split Joint (same pattern as tank console_cradle.scad)
// =====================================================

module split_keys_male() {
    key_y1 = TCONSOLE_DEPTH * 0.25;
    key_y2 = TCONSOLE_DEPTH * 0.75;
    key_z  = TCONSOLE_HEIGHT * 0.33;

    translate([half_width, key_y1, key_z])
        rotate([0, 90, 0])
            split_key(size=key_size, height=key_height);
    translate([half_width, key_y2, key_z])
        rotate([0, 90, 0])
            split_key(size=key_size, height=key_height);
}

module split_sockets_female() {
    key_y1 = TCONSOLE_DEPTH * 0.25;
    key_y2 = TCONSOLE_DEPTH * 0.75;
    key_z  = TCONSOLE_HEIGHT * 0.33;

    translate([0, key_y1, key_z])
        rotate([0, 90, 0])
            split_socket(size=key_size, height=key_height);
    translate([0, key_y2, key_z])
        rotate([0, 90, 0])
            split_socket(size=key_size, height=key_height);
}

module split_bolts_left() {
    bolt_y1 = TCONSOLE_DEPTH * 0.25;
    bolt_y2 = TCONSOLE_DEPTH * 0.75;
    bolt_z  = TCONSOLE_HEIGHT * 0.66;

    translate([half_width - bolt_depth / 2, bolt_y1, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
    translate([half_width - bolt_depth / 2, bolt_y2, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
}

module split_bolts_right() {
    bolt_y1 = TCONSOLE_DEPTH * 0.25;
    bolt_y2 = TCONSOLE_DEPTH * 0.75;
    bolt_z  = TCONSOLE_HEIGHT * 0.66;

    translate([-bolt_depth / 2, bolt_y1, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
    translate([-bolt_depth / 2, bolt_y2, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
}

// =====================================================
// Dummy Component Visualization
// =====================================================

module show_components() {
    // Display dummy
    color("DarkSlateGray", 0.4)
    translate([disp_x, disp_y, disp_z])
    rotate([-display_tilt, 0, 0])
        rpi_display_7in_dummy();

    // RPi4 dummy
    color("Green", 0.4)
    translate([rpi_x, rpi_y, rpi_z + rpi_standoff_h])
        rpi4_dummy();

    // PS2 joystick dummy
    color("Blue", 0.4)
    translate([joy_x, joy_y, joy_z - PS2_JOY_PCB_H])
        ps2_joystick_dummy();

    // MCP3008 dummy
    color("Red", 0.4)
    translate([mcp_x, mcp_y, mcp_z + 5])
        mcp3008_dummy();

    // Anker battery dummy
    color("Gray", 0.3)
    translate([batt_x, batt_y, batt_z])
        anker_slim10000_dummy();
}

// =====================================================
// Half Assemblies
// =====================================================

module console_left() {
    difference() {
        union() {
            console_base_half();
            // Alignment keys
            split_keys_male();
            // Battery retaining lips (left portion)
            intersection() {
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
                battery_bay_cradle();
            }
            // Display mount standoffs (left portion)
            intersection() {
                cube([half_width + 0.1, TCONSOLE_DEPTH + 50, TCONSOLE_HEIGHT + 50]);
                display_mount_standoffs();
            }
            // RPi4 mount standoffs (left portion)
            intersection() {
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
                rpi4_mount_area();
            }
            // Joystick mount (left portion)
            intersection() {
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
                joystick_mount_area();
            }
        }

        // Display frame cutout (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 50, TCONSOLE_HEIGHT + 50]);
            display_frame_cutout();
        }

        // Joystick panel cutout (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            joystick_panel_cutout();
        }

        // Battery bay (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            battery_bay();
        }

        // Ribbon cable channel (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            ribbon_cable_channel();
        }

        // GPIO cable channel (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            gpio_cable_channel();
        }

        // RPi4 ventilation (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            rpi4_ventilation();
        }

        // Side ventilation (left wall)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            side_ventilation();
        }

        // USB-C pass-through (left portion)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            usbc_passthrough();
        }

        // Rubber feet (left side)
        intersection() {
            cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            rubber_feet_recesses();
        }

        // Split bolt holes
        split_bolts_left();
    }
}

module console_right() {
    // Right half — origin at seam, extends to +half_width
    difference() {
        union() {
            console_base_half();
            // Battery retaining lips (right portion)
            intersection() {
                translate([-0.1, 0, 0])
                    cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
                translate([-half_width, 0, 0])
                    battery_bay_cradle();
            }
            // Display mount standoffs (right portion)
            intersection() {
                translate([-0.1, 0, 0])
                    cube([half_width + 0.1, TCONSOLE_DEPTH + 50, TCONSOLE_HEIGHT + 50]);
                translate([-half_width, 0, 0])
                    display_mount_standoffs();
            }
            // RPi4 mount standoffs (right portion)
            intersection() {
                translate([-0.1, 0, 0])
                    cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
                translate([-half_width, 0, 0])
                    rpi4_mount_area();
            }
            // MCP3008 mount (right portion)
            intersection() {
                translate([-0.1, 0, 0])
                    cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
                translate([-half_width, 0, 0])
                    mcp3008_mount_area();
            }
        }

        // Alignment sockets
        split_sockets_female();

        // Display frame cutout (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 50, TCONSOLE_HEIGHT + 50]);
            translate([-half_width, 0, 0])
                display_frame_cutout();
        }

        // Joystick panel cutout (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                joystick_panel_cutout();
        }

        // Battery bay (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                battery_bay();
        }

        // Ribbon cable channel (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                ribbon_cable_channel();
        }

        // GPIO cable channel (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                gpio_cable_channel();
        }

        // RPi4 ventilation (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                rpi4_ventilation();
        }

        // Side ventilation (right wall)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                side_ventilation();
        }

        // USB-C pass-through (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                usbc_passthrough();
        }

        // Rubber feet (right side)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, TCONSOLE_DEPTH + 10, TCONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                rubber_feet_recesses();
        }

        // Split bolt holes
        split_bolts_right();
    }
}

module console_assembly() {
    console_left();
    translate([half_width, 0, 0])
        console_right();

    // Show component dummies in assembly view
    show_components();
}

// =====================================================
// Render selected part
// =====================================================
if (part == "left") console_left();
else if (part == "right") console_right();
else if (part == "assembly") console_assembly();
