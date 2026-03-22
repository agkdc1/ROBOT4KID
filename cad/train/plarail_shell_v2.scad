// =====================================================================
// Plarail Smart FPV Train — Shell (Top Cover)  v2
// Shinkansen N700-inspired streamlined profile
// Self-contained — no external library dependencies
// All dimensions in millimeters.  $fn = 48 for curves.
// =====================================================================

$fn = 48;

// --- Part Selector ---
// "shell"    — shell only (flipped for printing, flat roof down)
// "chassis"  — chassis only (uses chassis file)
// "assembly" — shell + chassis + ghost components
part = "assembly";

// =====================================================================
// Print / Tolerance  (must match chassis file exactly)
// =====================================================================
PRINT_TOL       = 0.20;
WALL            = 1.60;
CLEARANCE       = 1.50;

// =====================================================================
// Plarail Track Standard (27 mm gauge per hardware_specs.yaml)
// =====================================================================
TRACK_GAUGE     = 27;
WHEEL_DIA       = 10;
WHEEL_WIDTH     = 3;
AXLE_DIA        = 2.0;
AXLE_HOLE       = AXLE_DIA + 2 * PRINT_TOL;
WHEEL_BOSS_OD   = 7;
WHEEL_BOSS_H    = 4;

// =====================================================================
// Body Envelope  (shared with chassis)
// =====================================================================
BODY_LENGTH     = 140;
BODY_WIDTH      = 33;
BODY_HEIGHT_TOT = 28;
SPLIT_Z         = 12;
FLOOR_T         = 1.6;
NOSE_LEN        = 30;
BODY_RECT_LEN   = BODY_LENGTH - NOSE_LEN;

// =====================================================================
// Shell Envelope
// =====================================================================
SHELL_HEIGHT    = BODY_HEIGHT_TOT - SPLIT_Z;  // 16 mm
ROOF_TAPER      = 2.5;   // Roof is narrower than body by this amount per side
ROOF_RADIUS     = 4;     // Roof edge rounding radius

// =====================================================================
// Nose Cone Parameters (N700 aerodynamic profile)
// =====================================================================
NOSE_TIP_W      = 6;     // Width at tip
NOSE_TIP_H      = 5;     // Height at tip
NOSE_TIP_DROP   = 6;     // Tip drops below body top line
NOSE_MID_FRAC   = 0.45;  // Mid-section at 45% of nose length
NOSE_MID_W_FRAC = 0.55;  // Mid-section width fraction
NOSE_MID_H_FRAC = 0.65;  // Mid-section height fraction

// =====================================================================
// Windshield Cutout (for ESP32-CAM lens)
// =====================================================================
WINDSHIELD_W    = 14;     // Width of windshield opening
WINDSHIELD_H    = 10;     // Height
WINDSHIELD_R    = 2;      // Corner radius
CAM_LENS_DIA    = 8;
CAM_TILT        = 10;     // Must match chassis tilt

// =====================================================================
// USB-C Access Port
// =====================================================================
USB_PORT_W      = 9;
USB_PORT_H      = 3.5;
CHRG_L          = 26;
CHRG_W          = 17;

// Position must match chassis TP4056 location
CHRG_X          = 3;       // MOTOR_X from chassis = 3

// =====================================================================
// Window Parameters
// =====================================================================
WINDOW_W        = 7;
WINDOW_H        = 5;
WINDOW_R        = 1.2;
WINDOW_SPACING  = 16;
WINDOW_COUNT    = 5;
WINDOW_Z_LOCAL  = 3;      // Z offset from split line (on shell)

// Window band (continuous recess)
WBAND_HEIGHT    = 6;
WBAND_DEPTH     = 0.3;
WBAND_Z_LOCAL   = 2;      // From split line

// =====================================================================
// Ventilation Grills
// =====================================================================
VENT_SLOT_L     = 18;     // Slot length
VENT_SLOT_W     = 1.5;    // Slot width
VENT_SPACING    = 4.5;
VENT_COUNT      = 5;
VENT_Z_LOCAL    = SHELL_HEIGHT - WALL - 1;  // Near roof

// =====================================================================
// M2 Screw Holes (must match chassis boss positions)
// =====================================================================
M2_HOLE         = 2.2;
M2_BOSS_OD      = 5.5;
M2_COUNTERSINK  = 4.2;    // Countersink diameter for M2

// Positions must match chassis
SCREW_POSITIONS = [
    [12,                    BODY_WIDTH/2 - M2_BOSS_OD/2 - 1],
    [12,                   -BODY_WIDTH/2 + M2_BOSS_OD/2 + 1],
    [BODY_RECT_LEN - 12,   BODY_WIDTH/2 - M2_BOSS_OD/2 - 1],
    [BODY_RECT_LEN - 12,  -BODY_WIDTH/2 + M2_BOSS_OD/2 + 1],
];

// =====================================================================
// Alignment Groove (mates with chassis ridge)
// =====================================================================
RIDGE_W         = 0.8 + PRINT_TOL;   // Slightly wider than chassis ridge
RIDGE_H         = 1.0 + PRINT_TOL;

// =====================================================================
// Decorative Features
// =====================================================================
PANEL_LINE_D    = 0.2;    // Panel line depth
PANEL_LINE_W    = 0.3;    // Panel line width

// =====================================================================
// Helper: Rounded Rectangle (2D)
// =====================================================================
module rrect_2d(w, h, r) {
    offset(r=r) offset(delta=-r)
        square([w, h], center=true);
}

// =====================================================================
// Shell Cross-Section (2D) — N700 profile with tapered roof
// =====================================================================
module shell_cross_section_2d() {
    // Cross-section from split line (Z=0 local) to roof
    // Bottom is BODY_WIDTH, roof is narrower
    roof_w = BODY_WIDTH - 2 * ROOF_TAPER;

    hull() {
        // Bottom edge (full width at split line)
        translate([-BODY_WIDTH/2, 0])
            square([BODY_WIDTH, 0.01]);

        // Side walls taper inward
        translate([-BODY_WIDTH/2, 0])
            square([BODY_WIDTH, SHELL_HEIGHT * 0.6]);

        // Roof edge (narrower, rounded)
        translate([-roof_w/2 + ROOF_RADIUS, SHELL_HEIGHT - ROOF_RADIUS])
            circle(r=ROOF_RADIUS);
        translate([roof_w/2 - ROOF_RADIUS, SHELL_HEIGHT - ROOF_RADIUS])
            circle(r=ROOF_RADIUS);
    }
}

// =====================================================================
// Shell Outer Form — rectangular section
// =====================================================================
module shell_body_outer() {
    translate([0, 0, SPLIT_Z])
        rotate([90, 0, 90])
            linear_extrude(height=BODY_RECT_LEN)
                shell_cross_section_2d();
}

// =====================================================================
// Shell Nose Cone — Shinkansen N700 taper
// =====================================================================
module shell_nose_cone() {
    translate([BODY_RECT_LEN, 0, SPLIT_Z]) {
        hull() {
            // Base junction — matches body cross-section
            rotate([90, 0, 90])
                linear_extrude(height=0.01)
                    shell_cross_section_2d();

            // Mid-section waypoint
            translate([NOSE_LEN * NOSE_MID_FRAC, 0, -NOSE_TIP_DROP * NOSE_MID_FRAC]) {
                mid_w = BODY_WIDTH * NOSE_MID_W_FRAC;
                mid_h = SHELL_HEIGHT * NOSE_MID_H_FRAC;
                mid_roof_w = mid_w - ROOF_TAPER;
                mid_r = min(2.5, mid_roof_w/4);

                rotate([90, 0, 90])
                    linear_extrude(height=0.01)
                        hull() {
                            translate([-mid_w/2, 0])
                                square([mid_w, 0.01]);
                            translate([-mid_roof_w/2 + mid_r, mid_h - mid_r])
                                circle(r=mid_r);
                            translate([mid_roof_w/2 - mid_r, mid_h - mid_r])
                                circle(r=mid_r);
                            translate([-mid_w/2, 0])
                                square([mid_w, 1]);
                        }
            }

            // Tip — small rounded shape, dropped
            translate([NOSE_LEN - 0.5, 0, -NOSE_TIP_DROP]) {
                tip_r = min(1.2, NOSE_TIP_W/4);
                rotate([90, 0, 90])
                    linear_extrude(height=0.5)
                        hull() {
                            translate([-NOSE_TIP_W/2 + tip_r, tip_r])
                                circle(r=tip_r);
                            translate([NOSE_TIP_W/2 - tip_r, tip_r])
                                circle(r=tip_r);
                            translate([-NOSE_TIP_W/2 + tip_r, NOSE_TIP_H - tip_r])
                                circle(r=tip_r);
                            translate([NOSE_TIP_W/2 - tip_r, NOSE_TIP_H - tip_r])
                                circle(r=tip_r);
                        }
            }
        }
    }
}

// =====================================================================
// Shell Outer (combined body + nose)
// =====================================================================
module shell_outer() {
    union() {
        shell_body_outer();
        shell_nose_cone();
    }
}

// =====================================================================
// Shell Interior Cavity (hollow out the shell)
// =====================================================================
module shell_interior() {
    iw = BODY_WIDTH - 2 * WALL;
    ih = SHELL_HEIGHT - WALL;  // Open at bottom (split line)
    il = BODY_RECT_LEN - WALL;

    // Main cavity
    translate([WALL/2, -iw/2, SPLIT_Z])
        cube([il, iw, ih]);

    // Nose cavity
    translate([BODY_RECT_LEN, 0, SPLIT_Z]) {
        hull() {
            translate([0, -(iw - 2)/2, 0])
                cube([0.01, iw - 2, ih - 2]);
            translate([NOSE_LEN - 12, -3, -NOSE_TIP_DROP * 0.4])
                cube([0.01, 6, NOSE_TIP_H - 2]);
        }
    }
}

// =====================================================================
// Windshield Cutout (front, for camera lens)
// =====================================================================
module windshield_cutout() {
    // Positioned on the nose, aligned with camera
    ws_x = BODY_RECT_LEN + NOSE_LEN * 0.15;
    ws_z = SPLIT_Z + 2;

    // Rectangular window with rounded corners
    translate([ws_x, 0, ws_z]) {
        rotate([0, -15, 0])  // Follow nose slope
            rotate([0, 90, 0])
                linear_extrude(height=WALL + 2)
                    rrect_2d(WINDSHIELD_W, WINDSHIELD_H, WINDSHIELD_R);
    }

    // Lens aperture (cylindrical, aligned with camera tilt)
    cam_center_z = FLOOR_T + 12/2 + 1;  // Approximate camera center from chassis
    translate([BODY_RECT_LEN - 2, 0, cam_center_z])
        rotate([0, -CAM_TILT, 0])
            rotate([0, 90, 0])
                cylinder(h=NOSE_LEN + 5, d=CAM_LENS_DIA + 3);
}

// =====================================================================
// Side Windows (decorative recesses)
// =====================================================================
module side_windows() {
    start_x = BODY_RECT_LEN - WINDOW_COUNT * WINDOW_SPACING - 5;

    for (i = [0 : WINDOW_COUNT - 1]) {
        x = start_x + i * WINDOW_SPACING;
        for (side = [-1, 1]) {
            y = side * BODY_WIDTH / 2;
            translate([x, y, SPLIT_Z + WINDOW_Z_LOCAL])
                rotate([90, 0, 0])
                    linear_extrude(height=WALL + 1, center=true)
                        hull() {
                            for (dx = [WINDOW_R, WINDOW_W - WINDOW_R])
                                for (dz = [WINDOW_R, WINDOW_H - WINDOW_R])
                                    translate([dx, dz])
                                        circle(r=WINDOW_R);
                        }
        }
    }
}

// =====================================================================
// Window Band (continuous recess along both sides)
// =====================================================================
module window_band() {
    band_len = BODY_RECT_LEN - 2 * WALL;

    for (side = [-1, 1]) {
        translate([WALL, side * (BODY_WIDTH/2 - WBAND_DEPTH + 0.01),
                   SPLIT_Z + WBAND_Z_LOCAL])
            cube([band_len, WBAND_DEPTH + 0.02, WBAND_HEIGHT]);
    }

    // Band continues into nose (first 25%)
    nose_band = NOSE_LEN * 0.25;
    for (side = [-1, 1]) {
        translate([BODY_RECT_LEN,
                   side * (BODY_WIDTH/2 - WBAND_DEPTH + 0.01),
                   SPLIT_Z + WBAND_Z_LOCAL])
            cube([nose_band, WBAND_DEPTH + 0.02, WBAND_HEIGHT]);
    }
}

// =====================================================================
// Ventilation Grills (roof slots for heat dissipation)
// =====================================================================
module vent_grills() {
    // Center cluster on roof
    start_x = BODY_RECT_LEN / 2 - (VENT_COUNT * VENT_SPACING) / 2;

    for (i = [0 : VENT_COUNT - 1]) {
        x = start_x + i * VENT_SPACING;
        translate([x, -VENT_SLOT_L/2, SPLIT_Z + SHELL_HEIGHT - WALL - 0.1])
            cube([VENT_SLOT_W, VENT_SLOT_L, WALL + 0.2]);
    }

    // Rear vent cluster (above motor area)
    rear_start = 8;
    for (i = [0 : 2]) {
        translate([rear_start + i * VENT_SPACING,
                   -VENT_SLOT_L * 0.6 / 2,
                   SPLIT_Z + SHELL_HEIGHT - WALL - 0.1])
            cube([VENT_SLOT_W, VENT_SLOT_L * 0.6, WALL + 0.2]);
    }
}

// =====================================================================
// USB-C Access Port (rear wall cutout for TP4056 charging)
// =====================================================================
module usb_access_port() {
    // TP4056 USB-C port faces the rear wall (X=0)
    chrg_y = BODY_WIDTH/2 - WALL - (CHRG_W + 1.5) - 0.5;
    port_center_y = chrg_y + (CHRG_W + 1.5) / 2;
    port_z = SPLIT_Z + 0.5;

    // Rear wall cutout
    translate([-0.5, port_center_y - USB_PORT_W/2 - 1, port_z])
        cube([WALL + 1, USB_PORT_W + 2, USB_PORT_H + 2]);

    // Label recess on rear face
    translate([-PANEL_LINE_D, port_center_y - USB_PORT_W/2 - 2, port_z + USB_PORT_H + 3])
        cube([PANEL_LINE_D + 0.1, USB_PORT_W + 4, 1.5]);
}

// =====================================================================
// M2 Screw Holes (countersunk from top)
// =====================================================================
module screw_holes() {
    for (pos = SCREW_POSITIONS) {
        translate([pos[0], pos[1], SPLIT_Z - 0.1]) {
            // Through-hole
            cylinder(h=SHELL_HEIGHT + 0.2, d=M2_HOLE);
            // Countersink at top
            translate([0, 0, SHELL_HEIGHT - 1.5])
                cylinder(h=2, d1=M2_HOLE, d2=M2_COUNTERSINK);
        }
    }
}

// =====================================================================
// Alignment Groove (mates with chassis ridge)
// =====================================================================
module alignment_groove() {
    groove_len = BODY_RECT_LEN - 2 * WALL - 10;

    // Left groove
    translate([WALL + 5, -BODY_WIDTH/2 + WALL, SPLIT_Z - 0.1])
        cube([groove_len, RIDGE_W, RIDGE_H + 0.1]);
    // Right groove
    translate([WALL + 5, BODY_WIDTH/2 - WALL - RIDGE_W, SPLIT_Z - 0.1])
        cube([groove_len, RIDGE_W, RIDGE_H + 0.1]);
}

// =====================================================================
// Panel Lines (decorative surface detail)
// =====================================================================
module panel_lines() {
    // Horizontal panel line at mid-height on both sides
    pl_z = SPLIT_Z + SHELL_HEIGHT * 0.45;
    pl_len = BODY_RECT_LEN - 10;

    for (side = [-1, 1]) {
        translate([5, side * (BODY_WIDTH/2 - PANEL_LINE_D + 0.01), pl_z])
            cube([pl_len, PANEL_LINE_D + 0.01, PANEL_LINE_W]);
    }

    // Vertical panel lines (door markers)
    for (x = [BODY_RECT_LEN * 0.3, BODY_RECT_LEN * 0.7]) {
        for (side = [-1, 1]) {
            translate([x, side * (BODY_WIDTH/2 - PANEL_LINE_D + 0.01),
                       SPLIT_Z + 1])
                cube([PANEL_LINE_W, PANEL_LINE_D + 0.01, SHELL_HEIGHT - 3]);
        }
    }
}

// =====================================================================
// Headlight Recesses (front nose)
// =====================================================================
module headlight_recesses() {
    // Two small circular recesses on the nose front
    hl_x = BODY_RECT_LEN + NOSE_LEN * 0.35;
    hl_z = SPLIT_Z + 2;
    hl_dia = 3;
    hl_depth = 1;

    for (side = [-1, 1]) {
        translate([hl_x, side * 5, hl_z])
            rotate([0, 90, 0])
                cylinder(h=hl_depth, d=hl_dia);
    }
}

// =====================================================================
// Rear Face Detail (tail lights, coupling access)
// =====================================================================
module rear_details() {
    // Tail light recesses
    tl_dia = 2.5;
    for (side = [-1, 1]) {
        translate([-0.5, side * 8, SPLIT_Z + SHELL_HEIGHT * 0.4])
            rotate([0, -90, 0])
                cylinder(h=1, d=tl_dia);
    }
}

// =====================================================================
// MAIN SHELL MODULE
// =====================================================================
module shell() {
    difference() {
        // Solid outer form
        shell_outer();

        // Hollow interior
        shell_interior();

        // Functional cutouts
        windshield_cutout();
        usb_access_port();
        screw_holes();
        alignment_groove();
        vent_grills();

        // Decorative features
        side_windows();
        window_band();
        panel_lines();
        headlight_recesses();
        rear_details();
    }
}

// =====================================================================
// Chassis (inline copy for assembly view — or use `use` if preferred)
// Minimal chassis representation for assembly preview
// =====================================================================
module chassis_placeholder() {
    // Simplified chassis block for assembly reference
    // The real chassis is in plarail_chassis_v2.scad
    color("LightGray", 0.8) {
        // Floor
        translate([0, -BODY_WIDTH/2, 0])
            cube([BODY_RECT_LEN, BODY_WIDTH, FLOOR_T]);
        // Nose floor
        hull() {
            translate([BODY_RECT_LEN, -BODY_WIDTH/2, 0])
                cube([0.01, BODY_WIDTH, FLOOR_T]);
            translate([BODY_LENGTH - 1, -4, 0])
                cube([1, 8, FLOOR_T]);
        }
        // Side walls
        translate([0, -BODY_WIDTH/2, FLOOR_T])
            cube([BODY_RECT_LEN, WALL, SPLIT_Z - FLOOR_T]);
        translate([0, BODY_WIDTH/2 - WALL, FLOOR_T])
            cube([BODY_RECT_LEN, WALL, SPLIT_Z - FLOOR_T]);
        // Rear wall
        translate([0, -BODY_WIDTH/2, FLOOR_T])
            cube([WALL, BODY_WIDTH, SPLIT_Z - FLOOR_T]);
        // Wheel bosses
        for (ax = [MOTOR_X + MOTOR_LEN, BODY_RECT_LEN - 12]) {
            for (side = [-1, 1]) {
                translate([ax, side * TRACK_GAUGE/2, -WHEEL_BOSS_H])
                    cylinder(h=WHEEL_BOSS_H + FLOOR_T, d=WHEEL_BOSS_OD);
            }
        }
    }
}

// =====================================================================
// Ghost Component Volumes
// =====================================================================
// Component dimensions
CAM_L           = 40;  CAM_W = 27;  CAM_H = 12;
BATT_L          = 48;  BATT_W = 30; BATT_H = 6;
MOTOR_X         = 3;
MOTOR_DIA       = 12;  MOTOR_LEN = 25;
MDRV_X          = 3;
MDRV_L          = 29;  MDRV_W = 23; MDRV_H = 15;
BOOST_L         = 36;  BOOST_W = 17; BOOST_H = 14;

// Layout positions (must match chassis)
BATT_X          = MOTOR_X + MOTOR_LEN + 2;  // X=30
BOOST_X         = BATT_X + 6;               // X=36
CAM_X           = BODY_RECT_LEN - 2;  // =108, within rectangular section

module ghost_components() {
    // ESP32-CAM
    color("ForestGreen", 0.35)
        translate([CAM_X - CAM_L, -CAM_W/2, FLOOR_T + 1])
            cube([CAM_L, CAM_W, CAM_H]);

    // Battery
    color("DodgerBlue", 0.35)
        translate([BATT_X, -BATT_W/2, FLOOR_T + 0.5])
            cube([BATT_L, BATT_W, BATT_H]);

    // MT3608 (on top of battery)
    color("Red", 0.3)
        translate([BOOST_X, -BOOST_W/2, FLOOR_T + BATT_H + 2])
            cube([BOOST_L, BOOST_W, BOOST_H]);

    // N20 Motor
    color("Silver", 0.35)
        translate([MOTOR_X, 0, FLOOR_T + (MOTOR_DIA + 1.5)/2])
            rotate([0, 90, 0])
                cylinder(h=MOTOR_LEN, d=MOTOR_DIA);

    // L9110S (Y-offset to left side)
    mdrv_y = -BODY_WIDTH/2 + WALL + 1;
    color("DarkGreen", 0.3)
        translate([MDRV_X, mdrv_y, FLOOR_T + 2])
            cube([MDRV_L, MDRV_W, MDRV_H]);

    // TP4056
    chrg_y = BODY_WIDTH/2 - WALL - (CHRG_W + 1.5) - 0.5;
    color("Purple", 0.3)
        translate([CHRG_X, chrg_y, FLOOR_T + 0.8])
            cube([CHRG_L, CHRG_W, 4]);

    // Wheels
    color("DimGray", 0.5)
    for (ax = [MOTOR_X + MOTOR_LEN, BODY_RECT_LEN - 12]) {
        for (side = [-1, 1]) {
            translate([ax, side * TRACK_GAUGE/2, -WHEEL_BOSS_H + WHEEL_DIA/2 - 2])
                rotate([90, 0, 0])
                    cylinder(h=WHEEL_WIDTH, d=WHEEL_DIA, center=true);
        }
    }
}

// =====================================================================
// Assembly View
// =====================================================================
module assembly_view() {
    // Chassis (placeholder)
    chassis_placeholder();

    // Shell (translucent)
    color("White", 0.55) shell();

    // Ghost components
    ghost_components();
}

// =====================================================================
// Part Selector
// =====================================================================
if (part == "shell") {
    // Flip for printing — flat roof surface down on print bed
    translate([0, 0, SPLIT_Z + SHELL_HEIGHT])
        rotate([180, 0, 0])
            shell();
} else if (part == "chassis") {
    // Show chassis placeholder (use real chassis file for printing)
    chassis_placeholder();
} else {
    // Assembly view
    assembly_view();
}
