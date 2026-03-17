// NL2Bot Shinkansen N700 Locomotive — Plarail Compatible
// Split top/bottom shell with snap-fit, internal component cavities
// Redesigned with aerodynamic "aero double-wing" nose cone,
// tapered roof cross-section, and window band groove.
// All dimensions in millimeters

use <../libs/common.scad>
use <../libs/electronics.scad>
use <../libs/mounts.scad>
use <../libs/m3_hardware.scad>

// --- Part Selector ---
// "top", "bottom", "assembly"
part = "assembly";

// --- Plarail Track Parameters (parametric) ---
TRACK_GAUGE        = 27;    // Rail-to-rail center distance
TRACK_WIDTH_TOTAL  = 40;    // Overall track width
WHEEL_DIA          = 10;    // Wheel outer diameter
WHEEL_SPACING      = 30;    // Axle center-to-center (front/rear)
AXLE_DIA           = 2.0;   // Axle shaft diameter
AXLE_HOLE_DIA      = AXLE_DIA + PRINT_TOLERANCE * 2;

// --- Body Dimensions ---
BODY_LENGTH        = 130;   // Standard Plarail car length
BODY_WIDTH         = 36;    // Fits between guide rails
BODY_HEIGHT        = 30;    // Total height (top + bottom combined)
SHELL_SPLIT_Z      = 14;    // Split line height (bottom shell height)
NOSE_LENGTH        = 35;    // Aerodynamic nose cone length (elongated duckbill taper)
BODY_MAIN_LENGTH   = BODY_LENGTH - NOSE_LENGTH; // Rectangular section

// --- Roof Taper ---
// N700 cross-section: roof is narrower than floor by this amount per side
ROOF_TAPER         = 2.5;   // mm inward on each side at the roofline
ROOF_RADIUS        = 6;     // Radius of the rounded roof edge

// --- Shell Parameters ---
WALL               = 1.6;   // 1.6mm for structural integrity (4 perimeters)
SNAP_TAB_W         = 6;     // Snap-fit tab width
SNAP_TAB_H         = 2;     // Snap-fit tab height
SNAP_TAB_D         = 1.0;   // Snap-fit detent depth
SNAP_TAB_COUNT     = 3;     // Tabs per side

// --- Internal Component Zones ---
// ESP32-CAM at front (nose area)
CAM_ZONE_L         = ESP32CAM_L + 4;
CAM_ZONE_W         = ESP32CAM_W + 4;
CAM_ZONE_H         = ESP32CAM_H + 6;

// 18650 battery in center
BATT_ZONE_L        = BATT_1CELL_L + 4;
BATT_ZONE_W        = BATT_1CELL_W + 4;
BATT_ZONE_H        = BATT_1CELL_H + 2;

// DRV8833 motor driver at rear
DRV_ZONE_L         = DRV8833_L + 4;
DRV_ZONE_W         = DRV8833_W + 4;
DRV_ZONE_H         = DRV8833_H + 6;

// --- Window Parameters ---
WINDOW_BAND_HEIGHT = 3;     // Height of the continuous window groove
WINDOW_BAND_DEPTH  = 0.3;   // Recess depth (decorative groove)
WINDOW_BAND_Z      = SHELL_SPLIT_Z + 5;  // ~60% of body height

// Individual windows (cut through the band)
WINDOW_W           = 8;
WINDOW_H           = 6;
WINDOW_R           = 1.5;
WINDOW_SPACING     = 14;
WINDOW_COUNT       = 5;
WINDOW_Z           = SHELL_SPLIT_Z + 4;  // Windows on top shell

// --- Ventilation Slots ---
VENT_L             = 20;
VENT_W             = 2;
VENT_SPACING       = 5;
VENT_COUNT         = 4;

// --- Wire Duct ---
DUCT_WIDTH         = 8;
DUCT_DEPTH         = 4;

// --- Wheel Boss ---
WHEEL_BOSS_H       = 5;     // Boss protrusion below bottom shell
WHEEL_BOSS_OD      = 8;     // Outer diameter of wheel bearing boss

// --- Nose Cone Parameters ---
NOSE_TIP_WIDTH     = 5;     // Width at the very tip (narrow duckbill)
NOSE_TIP_HEIGHT    = 6;     // Height at the very tip (low profile)
NOSE_TIP_DROP      = 8;     // How far the tip drops below body centerline (steep downslope)
NOSE_HULL_STEPS    = 1;     // hull() does the smooth interpolation

// --- Nose Mid-Section Waypoint (50% of nose length) ---
NOSE_MID_FRAC      = 0.5;   // Position along nose length (0=base, 1=tip)
NOSE_MID_W_FRAC    = 0.6;   // Mid-section width as fraction of body width
NOSE_MID_H_FRAC    = 0.7;   // Mid-section height as fraction of body height

// =====================================================================
// Body Cross-Section (with tapered roof)
// N700 profile: floor is BODY_WIDTH, roof is (BODY_WIDTH - 2*ROOF_TAPER)
// =====================================================================
module body_cross_section_2d() {
    // 2D cross-section of the N700 body (centered on Y=0)
    // Bottom edge at Z=0, top edge at Z=BODY_HEIGHT
    roof_w = BODY_WIDTH - 2 * ROOF_TAPER;

    hull() {
        // Bottom-left corner
        translate([-BODY_WIDTH/2, 0])
            square([BODY_WIDTH, 0.01]);
        // Top edge (narrower, with rounded corners via circles)
        translate([-roof_w/2 + ROOF_RADIUS, BODY_HEIGHT - ROOF_RADIUS])
            circle(r=ROOF_RADIUS, $fn=32);
        translate([roof_w/2 - ROOF_RADIUS, BODY_HEIGHT - ROOF_RADIUS])
            circle(r=ROOF_RADIUS, $fn=32);
        // Flat bottom for stability
        translate([-BODY_WIDTH/2, 0])
            square([BODY_WIDTH, 1]);
    }
}

// =====================================================================
// Main Body (rectangular section with tapered roof cross-section)
// =====================================================================
module body_main_outer() {
    // Extrude the tapered cross-section along the body length
    // Body extends from X=0 to X=BODY_MAIN_LENGTH
    // Cross-section is in the YZ plane
    translate([0, 0, 0])
        rotate([90, 0, 90])
            linear_extrude(height=BODY_MAIN_LENGTH)
                body_cross_section_2d();
}

// =====================================================================
// Nose Cone — Shinkansen N700 "Aero Double-Wing" Style
// Uses hull() to smoothly taper from body cross-section to pointed tip
// =====================================================================
module nose_cone() {
    // The nose starts at X=0 (junction with body_main) and extends to X=NOSE_LENGTH
    // Tip is narrower, shorter, and drops below centerline

    tip_z_offset = -NOSE_TIP_DROP;  // Tip drops below body center

    hull() {
        // Base face: match the body cross-section exactly (thin slice)
        translate([0, 0, 0])
            rotate([90, 0, 90])
                linear_extrude(height=0.01)
                    body_cross_section_2d();

        // Mid-section waypoint at 50% nose length: creates the distinctive curved taper
        translate([NOSE_LENGTH * NOSE_MID_FRAC, 0, tip_z_offset * NOSE_MID_FRAC])
            rotate([90, 0, 90])
                linear_extrude(height=0.01)
                    hull() {
                        mid_w = BODY_WIDTH * NOSE_MID_W_FRAC;
                        mid_h = BODY_HEIGHT * NOSE_MID_H_FRAC;
                        mid_roof_w = mid_w - ROOF_TAPER;
                        mid_r = min(3, mid_roof_w/4);
                        translate([-mid_w/2, 0])
                            square([mid_w, 0.01]);
                        translate([-mid_roof_w/2 + mid_r, mid_h - mid_r])
                            circle(r=mid_r, $fn=24);
                        translate([mid_roof_w/2 - mid_r, mid_h - mid_r])
                            circle(r=mid_r, $fn=24);
                        translate([-mid_w/2, 0])
                            square([mid_w, 1]);
                    }

        // Tip: small rounded rectangle, dropped below centerline
        translate([NOSE_LENGTH - 0.5, 0, tip_z_offset])
            rotate([90, 0, 90])
                linear_extrude(height=0.5)
                    hull() {
                        tip_r = min(1.5, NOSE_TIP_WIDTH/4);
                        translate([-NOSE_TIP_WIDTH/2 + tip_r, tip_r])
                            circle(r=tip_r, $fn=24);
                        translate([NOSE_TIP_WIDTH/2 - tip_r, tip_r])
                            circle(r=tip_r, $fn=24);
                        translate([-NOSE_TIP_WIDTH/2 + tip_r, NOSE_TIP_HEIGHT - tip_r])
                            circle(r=tip_r, $fn=24);
                        translate([NOSE_TIP_WIDTH/2 - tip_r, NOSE_TIP_HEIGHT - tip_r])
                            circle(r=tip_r, $fn=24);
                    }
    }
}

// =====================================================================
// Full Outer Shell (body + nose)
// =====================================================================
module outer_shell() {
    union() {
        // Main rectangular section (origin at rear end)
        body_main_outer();
        // Nose cone at front
        translate([BODY_MAIN_LENGTH, 0, 0])
            nose_cone();
    }
}

// =====================================================================
// Interior Cavity
// =====================================================================
module interior_cavity() {
    w_inner = BODY_WIDTH - 2 * WALL;
    h_inner = BODY_HEIGHT - 2 * WALL;
    l_inner = BODY_MAIN_LENGTH - WALL;

    // Main cavity
    translate([WALL, -w_inner/2, WALL])
        cube([l_inner, w_inner, h_inner]);

    // Nose cavity (follows taper, slightly smaller than outer)
    nose_cav_wall = WALL + 0.5;
    translate([BODY_MAIN_LENGTH, 0, 0])
        hull() {
            // Base face
            translate([0, 0, 0])
                translate([0, -(w_inner - 2)/2, WALL + 1])
                    cube([0.01, w_inner - 2, h_inner - 4]);
            // Near-tip: small cavity
            translate([NOSE_LENGTH - 10, 0, NOSE_TIP_DROP * -0.5])
                translate([0, -4, WALL + 3])
                    cube([0.01, 8, NOSE_TIP_HEIGHT - 4]);
        }
}

// =====================================================================
// Snap-Fit Features
// =====================================================================
module snap_tabs_male() {
    // Tabs on bottom shell rim (along both long sides)
    tab_positions = [for (i = [0 : SNAP_TAB_COUNT - 1])
        BODY_MAIN_LENGTH * (i + 0.5) / SNAP_TAB_COUNT];

    for (x = tab_positions) {
        for (y_sign = [-1, 1]) {
            y = y_sign * (BODY_WIDTH/2 - WALL/2);
            translate([x - SNAP_TAB_W/2, y - 0.5, SHELL_SPLIT_Z - SNAP_TAB_H])
                difference() {
                    cube([SNAP_TAB_W, 1, SNAP_TAB_H]);
                    // Detent bump
                    translate([SNAP_TAB_W/2, y_sign > 0 ? 1 : 0, SNAP_TAB_H * 0.3])
                        rotate([0, 90, 0])
                            cylinder(h=SNAP_TAB_W, d=SNAP_TAB_D, center=true);
                }
        }
    }
}

module snap_tabs_female() {
    // Slots in top shell rim
    tol = PRINT_TOLERANCE;
    tab_positions = [for (i = [0 : SNAP_TAB_COUNT - 1])
        BODY_MAIN_LENGTH * (i + 0.5) / SNAP_TAB_COUNT];

    for (x = tab_positions) {
        for (y_sign = [-1, 1]) {
            y = y_sign * (BODY_WIDTH/2 - WALL/2);
            translate([x - SNAP_TAB_W/2 - tol, y - 0.5 - tol, SHELL_SPLIT_Z - SNAP_TAB_H - tol])
                cube([SNAP_TAB_W + 2*tol, 1 + 2*tol, SNAP_TAB_H + tol]);
        }
    }
}

// =====================================================================
// Window Band (continuous recessed groove along both sides)
// =====================================================================
module window_band() {
    // Continuous groove running the length of the main body
    // at ~60% height, 0.3mm deep, 3mm tall
    for (y_sign = [-1, 1]) {
        translate([WALL, y_sign * (BODY_WIDTH/2 - WINDOW_BAND_DEPTH + 0.01),
                   WINDOW_BAND_Z - WINDOW_BAND_HEIGHT/2])
            cube([BODY_MAIN_LENGTH - 2*WALL,
                  WINDOW_BAND_DEPTH + 0.02,
                  WINDOW_BAND_HEIGHT]);
    }

    // Extend the band partway into the nose (first 30% of nose length)
    nose_band_len = NOSE_LENGTH * 0.3;
    for (y_sign = [-1, 1]) {
        // The nose tapers, so the band surface is not at BODY_WIDTH/2 anymore.
        // Approximate: at the start of the nose it's still at BODY_WIDTH/2
        translate([BODY_MAIN_LENGTH, y_sign * (BODY_WIDTH/2 - WINDOW_BAND_DEPTH + 0.01),
                   WINDOW_BAND_Z - WINDOW_BAND_HEIGHT/2])
            cube([nose_band_len,
                  WINDOW_BAND_DEPTH + 0.02,
                  WINDOW_BAND_HEIGHT]);
    }
}

// =====================================================================
// Windows (decorative cutouts on both sides, through the band)
// =====================================================================
module side_windows() {
    start_x = BODY_MAIN_LENGTH - WINDOW_COUNT * WINDOW_SPACING;
    for (i = [0 : WINDOW_COUNT - 1]) {
        x = start_x + i * WINDOW_SPACING;
        for (y_sign = [-1, 1]) {
            y = y_sign * BODY_WIDTH/2;
            translate([x, y - WALL, WINDOW_Z])
                rotate([90, 0, 0])
                    hull() {
                        for (dx = [WINDOW_R, WINDOW_W - WINDOW_R])
                            for (dz = [WINDOW_R, WINDOW_H - WINDOW_R])
                                translate([dx, dz, 0])
                                    cylinder(h=WALL + 2, r=WINDOW_R, center=true);
                    }
        }
    }
}

// =====================================================================
// Ventilation Slots (top shell)
// =====================================================================
module vent_slots() {
    start_x = BODY_MAIN_LENGTH/2 - (VENT_COUNT * VENT_SPACING)/2;
    for (i = [0 : VENT_COUNT - 1]) {
        x = start_x + i * VENT_SPACING;
        translate([x, -VENT_L/2, BODY_HEIGHT - WALL - 0.1])
            cube([VENT_W, VENT_L, WALL + 0.2]);
    }
}

// =====================================================================
// Wire Duct Channels (bottom shell)
// =====================================================================
module wire_ducts() {
    // Center channel running length of bottom shell
    translate([WALL + 5, -DUCT_WIDTH/2, WALL])
        cube([BODY_MAIN_LENGTH - 2 * WALL - 10, DUCT_WIDTH, DUCT_DEPTH]);

    // Cross channel at battery/driver boundary
    batt_end_x = WALL + 10 + BATT_ZONE_L;
    translate([batt_end_x, -(BODY_WIDTH/2 - 2*WALL), WALL])
        cube([6, BODY_WIDTH - 4*WALL, DUCT_DEPTH]);
}

// =====================================================================
// Wheel Bosses and Axle Holes (bottom shell)
// =====================================================================
module wheel_bosses() {
    // Two axle positions (front and rear bogie)
    axle_x_rear  = 15;
    axle_x_front = 15 + WHEEL_SPACING;

    for (ax = [axle_x_rear, axle_x_front]) {
        // Axle bearing bosses on each side
        for (y_sign = [-1, 1]) {
            y = y_sign * TRACK_GAUGE/2;
            translate([ax, y, -WHEEL_BOSS_H])
                difference() {
                    cylinder(h=WHEEL_BOSS_H + WALL, d=WHEEL_BOSS_OD);
                    translate([0, 0, -0.05])
                        cylinder(h=WHEEL_BOSS_H + WALL + 0.1, d=AXLE_HOLE_DIA);
                }
        }
        // Axle channel between bosses (slot in floor)
        translate([ax - AXLE_HOLE_DIA/2, -TRACK_GAUGE/2, -0.05])
            cube([AXLE_HOLE_DIA, TRACK_GAUGE, WALL + 0.1]);
    }
}

// =====================================================================
// Component Cavities (for internal layout reference)
// =====================================================================
module component_cavities() {
    // ESP32-CAM cavity (front/nose area)
    cam_x = BODY_MAIN_LENGTH - 5;
    translate([cam_x, -CAM_ZONE_W/2, WALL])
        cube([CAM_ZONE_L, CAM_ZONE_W, CAM_ZONE_H]);

    // Lens aperture through nose
    translate([BODY_LENGTH - 2, 0, WALL + CAM_ZONE_H/2 + 2])
        rotate([0, 90, 0])
            cylinder(h=10, d=ESP32CAM_LENS_DIA + 4);

    // 18650 battery cavity (center)
    batt_x = (BODY_MAIN_LENGTH - BATT_ZONE_L) / 2;
    translate([batt_x, -BATT_ZONE_W/2, WALL])
        cube([BATT_ZONE_L, BATT_ZONE_W, BATT_ZONE_H]);

    // DRV8833 cavity (rear)
    translate([WALL + 2, -DRV_ZONE_W/2, WALL])
        cube([DRV_ZONE_L, DRV_ZONE_W, DRV_ZONE_H]);
}

// =====================================================================
// Lens Aperture (through nose for camera)
// =====================================================================
module lens_aperture() {
    // Aperture positioned to align with ESP32-CAM lens in the nose
    // The nose tip drops, so the aperture is at roughly the nose tip center
    translate([BODY_LENGTH - 5, 0, SHELL_SPLIT_Z * 0.7])
        rotate([0, 90, 0])
            cylinder(h=15, d=ESP32CAM_LENS_DIA + 3);
}

// =====================================================================
// Bottom Shell
// =====================================================================
module bottom_shell() {
    difference() {
        union() {
            // Outer form, cut at split line
            intersection() {
                outer_shell();
                translate([-1, -BODY_WIDTH, -WHEEL_BOSS_H - 1])
                    cube([BODY_LENGTH + 2, BODY_WIDTH * 2, SHELL_SPLIT_Z + WHEEL_BOSS_H + 1]);
            }
            // Snap-fit tabs (male)
            snap_tabs_male();
            // Wheel bosses
            wheel_bosses();
        }
        // Interior cavity
        interior_cavity();
        // Component cavities
        component_cavities();
        // Wire duct channels
        wire_ducts();
        // Lens aperture
        lens_aperture();
    }
}

// =====================================================================
// Top Shell
// =====================================================================
module top_shell() {
    difference() {
        // Outer form, above split line
        intersection() {
            outer_shell();
            translate([-1, -BODY_WIDTH, SHELL_SPLIT_Z])
                cube([BODY_LENGTH + 2, BODY_WIDTH * 2, BODY_HEIGHT]);
        }
        // Interior cavity
        interior_cavity();
        // Snap-fit slots (female)
        snap_tabs_female();
        // Window band groove (continuous recess)
        window_band();
        // Side windows (deeper cutouts through the band)
        side_windows();
        // Ventilation slots
        vent_slots();
        // Lens aperture (upper half)
        lens_aperture();
    }
}

// =====================================================================
// Assembly View
// =====================================================================
module assembly() {
    // Bottom shell (opaque)
    color("LightGray") bottom_shell();
    // Top shell (translucent for visibility)
    color("White", 0.7) top_shell();

    // Ghost volumes for components
    // ESP32-CAM
    cam_x = BODY_MAIN_LENGTH - 5;
    %translate([cam_x + 2, -ESP32CAM_W/2, WALL + 2])
        esp32cam_dummy();
    // Battery
    batt_x = (BODY_MAIN_LENGTH - BATT_1CELL_L) / 2;
    %translate([batt_x, -BATT_1CELL_W/2, WALL + 1])
        battery_holder_1cell_dummy();
    // DRV8833
    %translate([WALL + 4, -DRV8833_W/2, WALL + 1])
        drv8833_dummy();
}

// =====================================================================
// Part Selector
// =====================================================================
if (part == "top") {
    // Flip top shell for printing (flat side down)
    translate([0, 0, BODY_HEIGHT])
        rotate([180, 0, 0])
            top_shell();
} else if (part == "bottom") {
    bottom_shell();
} else {
    assembly();
}
