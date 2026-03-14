// NL2Bot Train — Single 18650 Battery Bay
// Friction-fit cradle for one 18650 cell, centered in locomotive body
// All dimensions in millimeters

use <../libs/common.scad>
use <../libs/electronics.scad>

// --- Battery Dimensions (from electronics.scad) ---
// BATT_1CELL_L = 77mm, BATT_1CELL_W = 21mm, BATT_1CELL_H = 20mm

// --- Bay Parameters ---
BAY_WALL           = 2.0;       // Cradle wall thickness
BAY_TOLERANCE      = 0.3;       // Slightly looser for easy battery swap
BAY_LIP            = 2.5;       // Retaining lip height at corners
SPRING_CLEARANCE   = 5;         // Extra length for spring terminals

// --- Wire Routing ---
WIRE_SLOT_W        = 6;         // Wire exit slot width
WIRE_SLOT_H        = 4;         // Wire exit slot height
WIRE_CHANNEL_W     = 6;         // Routing channel width
WIRE_CHANNEL_D     = 3;         // Routing channel depth
WIRE_CHANNEL_L     = 15;        // Channel length to adjacent zones

// --- Computed Dimensions ---
INNER_L            = BATT_1CELL_L + 2 * BAY_TOLERANCE + SPRING_CLEARANCE;
INNER_W            = BATT_1CELL_W + 2 * BAY_TOLERANCE;
OUTER_L            = INNER_L + 2 * BAY_WALL;
OUTER_W            = INNER_W + 2 * BAY_WALL;
CRADLE_H           = BATT_1CELL_H * 0.65;   // Hold ~65% of battery height

// =====================================================================
// Battery Cradle
// =====================================================================
module battery_cradle() {
    difference() {
        union() {
            // Outer walls
            cube([OUTER_L, OUTER_W, CRADLE_H]);

            // Retaining lips at 4 corners
            for (x = [0, OUTER_L - BAY_WALL])
                for (y = [0, OUTER_W - BAY_WALL])
                    translate([x, y, CRADLE_H])
                        cube([BAY_WALL, BAY_WALL, BAY_LIP]);

            // Center retention bumps on long walls (gentle inward press)
            for (y_pos = [0, OUTER_W - BAY_WALL]) {
                translate([OUTER_L/2 - 4, y_pos, CRADLE_H * 0.4])
                    rotate([y_pos > 0 ? 0 : 180, 0, 0])
                        translate([0, y_pos > 0 ? 0 : -BAY_WALL, 0])
                            cube([8, BAY_WALL, CRADLE_H * 0.4]);
            }
        }

        // Inner cavity
        translate([BAY_WALL, BAY_WALL, BAY_WALL])
            cube([INNER_L, INNER_W, CRADLE_H + BAY_LIP + 0.1]);

        // Wire exit slots (both short ends for spring terminal wires)
        // Front end
        translate([-0.05, BAY_WALL + INNER_W/2 - WIRE_SLOT_W/2, BAY_WALL])
            cube([BAY_WALL + 0.1, WIRE_SLOT_W, WIRE_SLOT_H]);
        // Rear end
        translate([OUTER_L - BAY_WALL - 0.05, BAY_WALL + INNER_W/2 - WIRE_SLOT_W/2, BAY_WALL])
            cube([BAY_WALL + 0.1, WIRE_SLOT_W, WIRE_SLOT_H]);
    }
}

// =====================================================================
// Wire Routing Channels
// =====================================================================
module wire_channels() {
    channel_wall = 1.2;

    // Forward channel (to ESP32-CAM power)
    translate([OUTER_L, OUTER_W/2 - WIRE_CHANNEL_W/2 - channel_wall, 0])
        difference() {
            cube([WIRE_CHANNEL_L, WIRE_CHANNEL_W + 2*channel_wall, WIRE_CHANNEL_D + channel_wall]);
            translate([-0.05, channel_wall, channel_wall])
                cube([WIRE_CHANNEL_L + 0.1, WIRE_CHANNEL_W, WIRE_CHANNEL_D + 0.1]);
        }

    // Rear channel (to DRV8833 power)
    translate([-WIRE_CHANNEL_L, OUTER_W/2 - WIRE_CHANNEL_W/2 - channel_wall, 0])
        difference() {
            cube([WIRE_CHANNEL_L, WIRE_CHANNEL_W + 2*channel_wall, WIRE_CHANNEL_D + channel_wall]);
            translate([-0.05, channel_wall, channel_wall])
                cube([WIRE_CHANNEL_L + 0.1, WIRE_CHANNEL_W, WIRE_CHANNEL_D + 0.1]);
        }
}

// =====================================================================
// Complete Battery Bay
// =====================================================================
module train_battery_bay() {
    battery_cradle();
    wire_channels();
}

// =====================================================================
// Render
// =====================================================================
train_battery_bay();

// Ghost: battery holder dummy for reference
%translate([BAY_WALL + BAY_TOLERANCE, BAY_WALL + BAY_TOLERANCE, BAY_WALL])
    battery_holder_1cell_dummy();

$fn = 64;
