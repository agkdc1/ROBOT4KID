// =====================================================================
// Plarail Smart FPV Train — Chassis (Bottom Half)  v2
// Self-contained — no external library dependencies
// All dimensions in millimeters.  $fn = 48 for curves.
// =====================================================================

$fn = 48;

// --- Part Selector ---
// "chassis"  — chassis only (print orientation)
// "shell"    — shell only  (imported from shell file; placeholder here)
// "assembly" — chassis + ghost components
part = "assembly";

// =====================================================================
// Print / Tolerance
// =====================================================================
PRINT_TOL       = 0.20;   // FDM print tolerance per side
WALL            = 1.60;   // Minimum wall thickness (4 perimeters on 0.4 nozzle)
CLEARANCE       = 1.50;   // Breathing room around each component

// =====================================================================
// Plarail Track Standard (38 mm gauge)
// =====================================================================
TRACK_GAUGE     = 38;     // Rail center-to-center
WHEEL_DIA       = 10;     // Outer diameter of Plarail wheel
WHEEL_WIDTH     = 3;      // Wheel thickness
AXLE_DIA        = 2.0;    // Shaft diameter
AXLE_HOLE       = AXLE_DIA + 2 * PRINT_TOL;  // Clearance hole
WHEEL_BOSS_OD   = 7;      // Bearing boss outer diameter
WHEEL_BOSS_H    = 4;      // Boss protrusion below floor

// =====================================================================
// Body Envelope
// =====================================================================
BODY_LENGTH     = 140;    // Total body length (nose tip to rear coupler)
BODY_WIDTH      = 33;     // Internal-clear width (fits inside 40 mm overall w/ wheels)
BODY_HEIGHT_TOT = 28;     // Total assembled height (chassis + shell)
SPLIT_Z         = 12;     // Split line height — chassis is 12 mm tall
FLOOR_T         = 1.6;    // Floor plate thickness
NOSE_LEN        = 30;     // Nose taper zone

// Derived
BODY_RECT_LEN   = BODY_LENGTH - NOSE_LEN;  // Rectangular section length

// =====================================================================
// Component Dimensions  (from datasheets, +CLEARANCE each side)
// =====================================================================

// ESP32-CAM — front FPV camera
CAM_L           = 40;     CAM_W  = 27;    CAM_H  = 12;
CAM_LENS_DIA    = 8;      // lens barrel diameter
CAM_TILT        = 10;     // degrees downward

// LP603048 LiPo Battery
BATT_L          = 48;     BATT_W = 30;    BATT_H = 6;

// MT3608 Boost Converter
BOOST_L         = 36;     BOOST_W = 17;   BOOST_H = 14;

// N20 Gear Motor (cylindrical, laid on side)
MOTOR_DIA       = 12;     MOTOR_LEN = 25;
MOTOR_SHAFT_DIA = 3;      MOTOR_SHAFT_LEN = 10;

// L9110S Motor Driver
MDRV_L          = 29;     MDRV_W = 23;    MDRV_H = 15;

// TP4056 USB-C Charging Module
CHRG_L          = 26;     CHRG_W = 17;    CHRG_H = 4;
USB_PORT_W      = 9;      USB_PORT_H = 3.5;  // USB-C port opening

// =====================================================================
// Wire Channel
// =====================================================================
WIRE_CH_W       = 2;      // 2 mm wire channel width
WIRE_CH_D       = 2.5;    // Channel depth from top of chassis wall

// =====================================================================
// M2 Screw Bosses
// =====================================================================
M2_HOLE         = 2.2;    // Clearance hole for M2 screw
M2_BOSS_OD      = 5.5;    // Boss outer diameter
M2_INSERT_HOLE  = 3.2;    // Heat-set insert hole (M2)
SCREW_BOSS_H    = SPLIT_Z - FLOOR_T; // Boss height from floor to split line

// =====================================================================
// Coupling (M2 screw-mounted Plarail hook/socket)
// =====================================================================
COUPLE_HOOK_L   = 8;      // Hook arm length
COUPLE_HOOK_W   = 6;      // Hook arm width
COUPLE_HOOK_H   = 3.5;    // Hook height (Plarail standard coupler height)
COUPLE_SOCKET_L = 9;      // Socket length
COUPLE_SOCKET_W = 7;      // Socket width (hook + clearance)
COUPLE_SOCKET_H = 4.5;    // Socket depth
COUPLE_MOUNT_L  = 12;     // Mount plate length
COUPLE_MOUNT_W  = 10;     // Mount plate width
COUPLE_SCREW_HOLE = 2.2;  // M2 clearance hole
COUPLE_Z        = 4.5;    // Coupler center height from rail (Plarail standard ~4-5mm)

// =====================================================================
// Micro Slide Switch (SS12D00 style, friction-fit)
// Placed after TP4056 OUT+, before MT3608 VIN+ (off-state charging)
// =====================================================================
SWITCH_L        = 7;       // Switch body length
SWITCH_W        = 3;       // Switch body width
SWITCH_H        = 3.5;     // Switch body height
SWITCH_KNOB_W   = 1.5;     // Knob protrusion
SWITCH_SLOT_TOL = 0.15;    // Friction-fit tolerance
SWITCH_GUARD_H  = 1.0;     // Dust guard lip height
SWITCH_SOLDER_CLR = 3;     // Clearance under switch for soldering
// Position: bottom of chassis, near rear (accessible when flipped)
SWITCH_X        = CHRG_X + CHRG_L + 2;  // After TP4056
SWITCH_Y        = 0;       // Centered

// =====================================================================
// Axle Positions (measured from rear of body = X=0)
// =====================================================================
AXLE_REAR_X     = 12;
AXLE_FRONT_X    = BODY_RECT_LEN - 12;
// Motor drives rear axle — motor sits just in front of rear axle

// =====================================================================
// Layout Positions  (X = 0 at rear, increases toward nose)
//
// Total interior X budget: ~106mm  (BODY_RECT_LEN - 2*WALL = 110 - 3.2)
//
// REAR ZONE  (X  3..30):  N20 motor (25mm) — centered on axle, Y-centered
//            (X  3..30):  L9110S (29mm) stacked ABOVE motor (Y-offset to fit)
//            (X  3..30):  TP4056 (26mm) beside motor (offset in Y toward side wall)
// MIDDLE     (X 32..80):  LP603048 battery (48mm) — on floor for low CG
//            (X 34..70):  MT3608 (36mm) — ABOVE battery
// FRONT      (X 68..108): ESP32-CAM (40mm) — tilted 10 deg down, lens toward nose
//
// Note: Battery (30mm wide) almost fills the 33mm body width, so MT3608 (17mm)
// sits on TOP of the battery, not beside it.  In the rear zone the motor (12mm dia)
// is Y-centered, L9110S is above it, and TP4056 is Y-offset to the right side wall.
// =====================================================================

// REAR ZONE  (X 3..28)
MOTOR_X         = 3;                         // Motor at rear (25mm, ends X=28)
MDRV_X          = 3;                         // L9110S same X span, Y-offset left
CHRG_X          = 3;                         // TP4056 same X span, Y-offset right

// MIDDLE ZONE  (X 30..78)
BATT_X          = MOTOR_X + MOTOR_LEN + 2;  // X=30, battery ends X=78
BOOST_X         = BATT_X + 6;               // MT3608 above battery (X=36..72)

// FRONT ZONE  (X 80..120)
// Camera rear edge at X=80 (2mm gap after battery), front edge at X=120
// Front 10mm extends into the nose zone — intentional for FPV lens alignment
CAM_X           = BATT_X + BATT_L + 2 + CAM_L; // = 30+48+2+40 = 120

// =====================================================================
// Helper: Rounded Rectangle (2D)
// =====================================================================
module rrect(w, h, r) {
    offset(r=r) offset(delta=-r)
        square([w, h], center=true);
}

// =====================================================================
// Chassis Floor Plate
// =====================================================================
module floor_plate() {
    // Rectangular section
    translate([0, -BODY_WIDTH/2, 0])
        cube([BODY_RECT_LEN, BODY_WIDTH, FLOOR_T]);

    // Nose taper (hull from rectangle to narrow tip)
    hull() {
        // Junction with body
        translate([BODY_RECT_LEN, -BODY_WIDTH/2, 0])
            cube([0.01, BODY_WIDTH, FLOOR_T]);
        // Tip
        translate([BODY_LENGTH - 1, -4, 0])
            cube([1, 8, FLOOR_T]);
    }
}

// =====================================================================
// Chassis Side Walls
// =====================================================================
module chassis_walls() {
    wall_h = SPLIT_Z - FLOOR_T;

    // Left wall
    translate([0, -BODY_WIDTH/2, FLOOR_T])
        cube([BODY_RECT_LEN, WALL, wall_h]);
    // Right wall
    translate([0, BODY_WIDTH/2 - WALL, FLOOR_T])
        cube([BODY_RECT_LEN, WALL, wall_h]);
    // Rear wall
    translate([0, -BODY_WIDTH/2, FLOOR_T])
        cube([WALL, BODY_WIDTH, wall_h]);

    // Nose walls (tapered)
    nose_wall_h = wall_h * 0.7; // Nose section is lower
    for (side = [-1, 1]) {
        hull() {
            // At body junction — full width
            translate([BODY_RECT_LEN, side * (BODY_WIDTH/2 - WALL), FLOOR_T])
                cube([0.01, WALL, nose_wall_h]);
            // At tip — narrow
            translate([BODY_LENGTH - 5, side * (4 - WALL/2), FLOOR_T])
                cube([0.01, WALL, nose_wall_h * 0.5]);
        }
    }
}

// =====================================================================
// Wire Channels (along both interior side walls)
// =====================================================================
module wire_channels() {
    ch_z = FLOOR_T;
    ch_len = BODY_RECT_LEN - 2 * WALL;

    // Left channel
    translate([WALL, -BODY_WIDTH/2 + WALL, ch_z])
        cube([ch_len, WIRE_CH_W, WIRE_CH_D]);
    // Right channel
    translate([WALL, BODY_WIDTH/2 - WALL - WIRE_CH_W, ch_z])
        cube([ch_len, WIRE_CH_W, WIRE_CH_D]);
}

// =====================================================================
// ESP32-CAM Cradle (front, tilted 10° down for FPV)
// =====================================================================
module cam_cradle() {
    // Pocket with 10° downward tilt
    cradle_w = CAM_W + CLEARANCE;
    cradle_l = CAM_L + CLEARANCE;
    cradle_h = CAM_H + 1;  // depth of pocket
    lip = 1.2;  // Retention lip height

    translate([CAM_X - cradle_l, 0, FLOOR_T]) {
        rotate([0, -CAM_TILT, 0]) {
            translate([0, -cradle_w/2, 0]) {
                difference() {
                    // Outer cradle walls
                    cube([cradle_l + 2*lip, cradle_w, cradle_h]);
                    // Inner pocket
                    translate([lip, lip, 0])
                        cube([cradle_l, cradle_w - 2*lip, cradle_h + 1]);
                    // Side relief for wires
                    translate([lip + 5, -0.1, 0])
                        cube([cradle_l - 10, lip + 0.2, cradle_h * 0.6]);
                    translate([lip + 5, cradle_w - lip - 0.1, 0])
                        cube([cradle_l - 10, lip + 0.2, cradle_h * 0.6]);
                }
                // Bottom support rails (two rails to hold the PCB)
                for (dy = [cradle_w * 0.25, cradle_w * 0.75]) {
                    translate([lip, dy - 0.5, 0])
                        cube([cradle_l, 1, 1]);
                }
            }
        }
    }

    // Lens window in front wall (through nose area)
    // (This is additive geometry for the cradle; the hole is cut in difference)
}

// =====================================================================
// Lens Aperture (cut through nose for camera)
// =====================================================================
module lens_aperture() {
    // Positioned at the nose to align with camera lens
    cam_center_z = FLOOR_T + CAM_H/2 + 1;
    translate([BODY_RECT_LEN - 2, 0, cam_center_z])
        rotate([0, CAM_TILT, 0])
            rotate([0, 90, 0])
                cylinder(h=NOSE_LEN + 5, d=CAM_LENS_DIA + 3);
}

// =====================================================================
// Battery Bay (recessed pocket for LP603048)
// =====================================================================
module battery_bay() {
    bay_l = BATT_L + CLEARANCE;
    bay_w = BATT_W + CLEARANCE;
    bay_h = BATT_H + 1;  // Slightly deeper than battery for wire routing

    // Floor recess to lower battery CG
    recess_depth = 0;  // Battery sits on floor (already low)

    translate([BATT_X, -bay_w/2, FLOOR_T]) {
        // Side retention walls
        retention_h = bay_h;
        retention_w = 1.2;

        // Left wall
        translate([-retention_w, -retention_w, 0])
            cube([bay_l + 2*retention_w, retention_w, retention_h]);
        // Right wall
        translate([-retention_w, bay_w, 0])
            cube([bay_l + 2*retention_w, retention_w, retention_h]);
        // Rear stop
        translate([-retention_w, 0, 0])
            cube([retention_w, bay_w, retention_h]);
        // Front stop with wire pass-through
        translate([bay_l, 0, 0])
            difference() {
                cube([retention_w, bay_w, retention_h]);
                // Wire slot
                translate([-0.1, bay_w/2 - 3, 0])
                    cube([retention_w + 0.2, 6, retention_h * 0.5]);
            }
        // Floor pads (raised dots to allow air gap under battery)
        for (dx = [bay_l * 0.2, bay_l * 0.8]) {
            for (dy = [bay_w * 0.3, bay_w * 0.7]) {
                translate([dx - 1, dy - 1, -0.01])
                    cylinder(h=0.6, d=2);
            }
        }
    }
}

// =====================================================================
// MT3608 Boost Converter Mount (on TOP of battery, centered in Y)
// =====================================================================
module boost_mount() {
    mount_l = BOOST_L + CLEARANCE;
    mount_w = BOOST_W + CLEARANCE;
    // Sits on top of battery: FLOOR_T + BATT_H + air gap
    base_z = FLOOR_T + BATT_H + 1.5;
    standoff_h = 1.5;  // Small standoff to clear solder joints

    translate([BOOST_X, -mount_w/2, base_z]) {
        // Two standoff rails
        cube([mount_l, 1.5, standoff_h]);
        translate([0, mount_w - 1.5, 0])
            cube([mount_l, 1.5, standoff_h]);

        // Retention clips at ends
        clip_h = standoff_h + 3;
        translate([-1, 0, 0])
            cube([1, mount_w, clip_h]);
        translate([mount_l, 0, 0])
            difference() {
                cube([1, mount_w, clip_h]);
                // Wire pass-through
                translate([-0.1, mount_w/2 - 2, 0])
                    cube([1.2, 4, clip_h * 0.5]);
            }
    }
}

// =====================================================================
// N20 Motor Clamp Cradle (rear, drives rear axle)
// =====================================================================
module motor_cradle() {
    // Motor lies on its side (shaft pointing down toward axle)
    cradle_id = MOTOR_DIA + CLEARANCE;
    cradle_od = cradle_id + 2 * WALL;
    cradle_len = MOTOR_LEN + CLEARANCE;

    translate([MOTOR_X, 0, FLOOR_T + cradle_od/2]) {
        rotate([0, 90, 0]) {
            difference() {
                // Outer cradle (bottom half-cylinder + flat base)
                union() {
                    // Half-cylinder cradle
                    difference() {
                        cylinder(h=cradle_len, d=cradle_od);
                        cylinder(h=cradle_len + 0.1, d=cradle_id);
                        // Cut top half away (motor drops in from top)
                        translate([0, -cradle_od/2, -0.1])
                            cube([cradle_od, cradle_od, cradle_len + 0.2]);
                    }
                    // Flat mounting base
                    translate([-cradle_od/2, -cradle_od/2, 0])
                        cube([cradle_od, WALL, cradle_len]);
                }
                // Shaft exit hole (rear)
                translate([0, 0, -1])
                    cylinder(h=WALL + 2, d=MOTOR_SHAFT_DIA + 1);
                // Shaft exit hole (front for gear)
                translate([0, 0, cradle_len - WALL - 1])
                    cylinder(h=WALL + 2, d=MOTOR_SHAFT_DIA + 1);
            }
        }
    }

    // Motor clamp strap (printed separately or snap-over)
    // Here we add two small posts for a zip-tie or rubber band
    for (dx = [5, cradle_len - 5]) {
        translate([MOTOR_X + dx, -cradle_od/2 - 1, FLOOR_T]) {
            cylinder(h=cradle_od + 4, d=2);
        }
        translate([MOTOR_X + dx, cradle_od/2 + 1, FLOOR_T]) {
            cylinder(h=cradle_od + 4, d=2);
        }
    }
}

// =====================================================================
// L9110S Motor Driver Mount (Y-offset to left side, above motor level)
// Motor is Y-centered (12mm dia); L9110S (23mm wide) is offset to the
// left side of the body to avoid collision.
// =====================================================================
module motor_driver_mount() {
    mount_l = MDRV_L + CLEARANCE;
    mount_w = MDRV_W + CLEARANCE;
    // L9110S sits beside motor, offset to left
    mdrv_y = -BODY_WIDTH/2 + WALL + 1;
    post_h  = 2;  // Standoff height

    translate([MDRV_X, mdrv_y, FLOOR_T]) {
        // Four corner standoffs
        for (dx = [1.5, mount_l - 1.5]) {
            for (dy = [1.5, mount_w - 1.5]) {
                translate([dx, dy, 0])
                    cylinder(h=post_h, d=3);
            }
        }
        // Side retention walls (partial height)
        ret_h = post_h + MDRV_H * 0.4;
        translate([0, -1, 0])
            cube([mount_l, 1, ret_h]);
        translate([0, mount_w, 0])
            cube([mount_l, 1, ret_h]);
    }
}

// =====================================================================
// TP4056 Charging Module Mount (Y-offset to right wall, USB-C facing out)
// TP4056 is 26x17x4mm — thin enough to fit beside the motor on the
// right side.  USB-C port faces the right side wall for external access.
// =====================================================================
module charger_mount() {
    mount_l = CHRG_L + CLEARANCE;
    mount_w = CHRG_W + CLEARANCE;

    // Right side, USB-C port flush with wall
    chrg_y = BODY_WIDTH/2 - WALL - mount_w - 0.5;

    translate([CHRG_X, chrg_y, FLOOR_T]) {
        // Mounting platform
        cube([mount_l, mount_w, 0.8]);

        // Side clips
        clip_h = CHRG_H + 1;
        translate([0, -0.8, 0])
            cube([mount_l, 0.8, clip_h]);
        translate([0, mount_w, 0])
            cube([mount_l, 0.8, clip_h]);

        // Front/rear stops
        translate([0, 0, 0])
            cube([1, mount_w, clip_h]);
        translate([mount_l - 1, 0, 0])
            cube([1, mount_w, clip_h]);
    }
}

// =====================================================================
// USB-C Access Window (cut through chassis side wall)
// =====================================================================
module usb_access_window() {
    // Hole in the right side wall aligned with TP4056 USB-C port
    // USB-C port is on the TP4056's long edge facing the right wall
    port_center_x = CHRG_X + (CHRG_L + CLEARANCE) / 2;
    port_z = FLOOR_T + 0.5;

    // Right wall cutout
    translate([port_center_x - USB_PORT_W/2 - 1,
               BODY_WIDTH/2 - WALL - 0.5,
               port_z])
        cube([USB_PORT_W + 2, WALL + 1, USB_PORT_H + 2]);
}

// =====================================================================
// M2 Screw Bosses (4 corners for shell attachment)
// =====================================================================
module screw_bosses() {
    boss_h = SPLIT_Z - FLOOR_T;

    positions = [
        [12,                  BODY_WIDTH/2 - M2_BOSS_OD/2 - 1],
        [12,                 -BODY_WIDTH/2 + M2_BOSS_OD/2 + 1],
        [BODY_RECT_LEN - 12, BODY_WIDTH/2 - M2_BOSS_OD/2 - 1],
        [BODY_RECT_LEN - 12,-BODY_WIDTH/2 + M2_BOSS_OD/2 + 1],
    ];

    for (pos = positions) {
        translate([pos[0], pos[1], FLOOR_T]) {
            difference() {
                cylinder(h=boss_h, d=M2_BOSS_OD);
                translate([0, 0, -0.1])
                    cylinder(h=boss_h + 0.2, d=M2_INSERT_HOLE);
            }
        }
    }
}

// =====================================================================
// Wheel Bosses and Axle Holes
// =====================================================================
module wheel_assemblies() {
    for (ax = [AXLE_REAR_X, AXLE_FRONT_X]) {
        for (side = [-1, 1]) {
            y = side * TRACK_GAUGE / 2;
            translate([ax, y, 0]) {
                // Boss protrudes below floor
                translate([0, 0, -WHEEL_BOSS_H])
                    difference() {
                        cylinder(h=WHEEL_BOSS_H + FLOOR_T + 1, d=WHEEL_BOSS_OD);
                        translate([0, 0, -0.1])
                            cylinder(h=WHEEL_BOSS_H + FLOOR_T + 1.2, d=AXLE_HOLE);
                    }
            }
        }
        // Axle slot through floor
        translate([ax - AXLE_HOLE/2, -TRACK_GAUGE/2, -0.1])
            cube([AXLE_HOLE, TRACK_GAUGE, FLOOR_T + 0.2]);
    }
}

// =====================================================================
// Plarail Coupling Features
// =====================================================================
module coupling_hook() {
    // Rear hook (M2 screw-mounted Plarail male coupling)
    // Mount plate bolts to chassis rear face via 2x M2 screws
    translate([-COUPLE_MOUNT_L, -COUPLE_MOUNT_W/2, FLOOR_T]) {
        difference() {
            union() {
                // Mount plate (screws to chassis)
                cube([COUPLE_MOUNT_L, COUPLE_MOUNT_W, COUPLE_HOOK_H + 1]);
                // Hook arm extending rearward
                translate([-COUPLE_HOOK_L, (COUPLE_MOUNT_W - COUPLE_HOOK_W)/2, 0])
                    cube([COUPLE_HOOK_L, COUPLE_HOOK_W, COUPLE_HOOK_H]);
                // Hook barb (downward catch)
                translate([-COUPLE_HOOK_L, COUPLE_MOUNT_W/2 - 1, -1.5])
                    cube([2, 2, COUPLE_HOOK_H + 1.5]);
            }
            // 2x M2 screw holes through mount plate
            translate([COUPLE_MOUNT_L/3, COUPLE_MOUNT_W/2, -1])
                cylinder(d=COUPLE_SCREW_HOLE, h=COUPLE_HOOK_H + 4);
            translate([2*COUPLE_MOUNT_L/3, COUPLE_MOUNT_W/2, -1])
                cylinder(d=COUPLE_SCREW_HOLE, h=COUPLE_HOOK_H + 4);
        }
    }
    // M2 screw bosses on chassis rear face (receive coupler screws)
    for (dx = [COUPLE_MOUNT_L/3, 2*COUPLE_MOUNT_L/3]) {
        translate([-dx, 0, FLOOR_T])
            difference() {
                cylinder(d=M2_BOSS_OD, h=COUPLE_HOOK_H + 1);
                translate([0, 0, -0.5])
                    cylinder(d=M2_INSERT_HOLE, h=COUPLE_HOOK_H + 2);
            }
    }
}

module coupling_socket() {
    // Front socket (M2 screw-mounted female coupling)
    // Mount plate at front, receives hook from next car
    translate([BODY_LENGTH - 2, -COUPLE_MOUNT_W/2, FLOOR_T - 0.5]) {
        difference() {
            // Socket block with slot
            cube([COUPLE_MOUNT_L, COUPLE_MOUNT_W, COUPLE_SOCKET_H]);
            // Hook slot (negative space for male hook to enter)
            translate([COUPLE_MOUNT_L - COUPLE_SOCKET_L - 0.5,
                       (COUPLE_MOUNT_W - COUPLE_SOCKET_W)/2, -0.5])
                cube([COUPLE_SOCKET_L + 1, COUPLE_SOCKET_W, COUPLE_SOCKET_H + 1]);
            // 2x M2 screw holes
            translate([COUPLE_MOUNT_L/3, COUPLE_MOUNT_W/2, -1])
                cylinder(d=COUPLE_SCREW_HOLE, h=COUPLE_SOCKET_H + 3);
            translate([2*COUPLE_MOUNT_L/3, COUPLE_MOUNT_W/2, -1])
                cylinder(d=COUPLE_SCREW_HOLE, h=COUPLE_SOCKET_H + 3);
        }
    }
}

module slide_switch_mount() {
    // SS12D00 micro slide switch — friction-fit slot in chassis bottom
    // Wiring: TP4056(OUT+) → switch → MT3608(VIN+) for off-state charging
    sw_x = SWITCH_X;
    sw_y = SWITCH_Y - SWITCH_L/2;

    // Switch pocket (cut from chassis floor)
    // Positive form: retainer walls around switch
    translate([sw_x, sw_y - SWITCH_SLOT_TOL, 0]) {
        difference() {
            // Retainer frame
            cube([SWITCH_W + 2*WALL, SWITCH_L + 2*SWITCH_SLOT_TOL + 2*WALL, FLOOR_T + SWITCH_H]);
            // Switch body cavity
            translate([WALL, WALL, -0.5])
                cube([SWITCH_W + 2*SWITCH_SLOT_TOL, SWITCH_L + 2*SWITCH_SLOT_TOL, SWITCH_H + 1]);
            // Knob slot (through floor for bottom access)
            translate([WALL + SWITCH_W/2 - 1, WALL, -0.5])
                cube([2, SWITCH_L + 2*SWITCH_SLOT_TOL, FLOOR_T + 1]);
        }
        // Dust guard lips (raised rim around knob slot on exterior)
        translate([WALL + SWITCH_W/2 - 1.5, WALL - 0.5, -SWITCH_GUARD_H])
            cube([3, SWITCH_L + 2*SWITCH_SLOT_TOL + 1, SWITCH_GUARD_H]);
    }
}

module switch_cutout() {
    // Cut through floor for switch knob access + soldering clearance
    sw_x = SWITCH_X;
    sw_y = SWITCH_Y - SWITCH_L/2;
    translate([sw_x + WALL - 0.5, sw_y - SWITCH_SLOT_TOL + WALL - 0.5, -0.5])
        cube([SWITCH_W + 2*SWITCH_SLOT_TOL + 1, SWITCH_L + 2*SWITCH_SLOT_TOL + 1, FLOOR_T + 1]);
}

// =====================================================================
// Alignment Ridge (for shell registration)
// =====================================================================
module alignment_ridge() {
    ridge_h = 1.0;
    ridge_w = 0.8;

    // Along left wall top edge
    translate([WALL + 5, -BODY_WIDTH/2 + WALL, SPLIT_Z - ridge_h])
        cube([BODY_RECT_LEN - 2*WALL - 10, ridge_w, ridge_h]);
    // Along right wall top edge
    translate([WALL + 5, BODY_WIDTH/2 - WALL - ridge_w, SPLIT_Z - ridge_h])
        cube([BODY_RECT_LEN - 2*WALL - 10, ridge_w, ridge_h]);
}

// =====================================================================
// MAIN CHASSIS MODULE
// =====================================================================
module chassis() {
    difference() {
        union() {
            // Structural elements
            floor_plate();
            chassis_walls();

            // Component mounts
            cam_cradle();
            battery_bay();
            boost_mount();
            motor_cradle();
            motor_driver_mount();
            charger_mount();

            // Assembly features
            screw_bosses();
            wheel_assemblies();
            coupling_hook();
            alignment_ridge();
            slide_switch_mount();
        }

        // Subtractive features
        lens_aperture();
        usb_access_window();
        wire_channels();
        coupling_socket();
        switch_cutout();
    }
}

// =====================================================================
// Ghost Component Volumes (for assembly visualization)
// =====================================================================
module ghost_esp32cam() {
    color("ForestGreen", 0.5)
        translate([CAM_X - CAM_L, -CAM_W/2, FLOOR_T + 1])
            rotate([0, -CAM_TILT, 0])
                cube([CAM_L, CAM_W, CAM_H]);
}

module ghost_battery() {
    color("DodgerBlue", 0.5)
        translate([BATT_X, -BATT_W/2, FLOOR_T + 0.5])
            cube([BATT_L, BATT_W, BATT_H]);
}

module ghost_mt3608() {
    color("Red", 0.4)
        translate([BOOST_X, -BOOST_W/2, FLOOR_T + BATT_H + 2])
            cube([BOOST_L, BOOST_W, BOOST_H]);
}

module ghost_motor() {
    color("Silver", 0.5)
        translate([MOTOR_X, 0, FLOOR_T + (MOTOR_DIA + CLEARANCE)/2])
            rotate([0, 90, 0])
                cylinder(h=MOTOR_LEN, d=MOTOR_DIA);
}

module ghost_l9110s() {
    // Y-offset to left side
    mdrv_y = -BODY_WIDTH/2 + WALL + 1;
    color("DarkGreen", 0.4)
        translate([MDRV_X, mdrv_y, FLOOR_T + 2])
            cube([MDRV_L, MDRV_W, MDRV_H]);
}

module ghost_tp4056() {
    chrg_y = BODY_WIDTH/2 - WALL - (CHRG_W + CLEARANCE) - 0.5;
    color("Purple", 0.4)
        translate([CHRG_X, chrg_y, FLOOR_T + 0.8])
            cube([CHRG_L, CHRG_W, CHRG_H]);
}

module ghost_wheels() {
    color("DimGray", 0.6)
    for (ax = [AXLE_REAR_X, AXLE_FRONT_X]) {
        for (side = [-1, 1]) {
            y = side * TRACK_GAUGE / 2;
            translate([ax, y, -WHEEL_BOSS_H + WHEEL_DIA/2 - 2])
                rotate([90, 0, 0])
                    cylinder(h=WHEEL_WIDTH, d=WHEEL_DIA, center=true);
        }
    }
}

// =====================================================================
// Assembly View
// =====================================================================
module assembly_view() {
    color("LightGray") chassis();

    // Ghost components
    ghost_esp32cam();
    ghost_battery();
    ghost_mt3608();
    ghost_motor();
    ghost_l9110s();
    ghost_tp4056();
    ghost_wheels();
}

// =====================================================================
// Part Selector
// =====================================================================
if (part == "chassis") {
    chassis();
} else if (part == "assembly") {
    assembly_view();
} else {
    chassis();
}
