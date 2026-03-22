// =====================================================================
// Handheld Gamepad Console — Kid-Friendly Tank Controller
// =====================================================================
// Landscape-oriented handheld gamepad for a 4-year-old child.
// Samsung Galaxy Tab A 8.0 S Pen (SM-P200) in tilted center cradle,
// dual PS2 joystick modules in ergonomic grips, 4x Sanwa 24mm buttons,
// SJ@JX 822B encoder, UGREEN Revodok 105 USB hub, TP-Link router, power bank.
//
// Three-piece split (left grip + center + right grip) for 180mm build
// volume compliance. Joined with M4 bolts and alignment keys.
//
// Parallel Power Architecture:
//   Circuit A (Data+PD): PowerBank USB-C PD → Hub PD-IN → Tablet
//   Circuit B (Joystick HID): Encoder USB → Hub USB-A → Tablet HID
//   Circuit C (Isolated AP): PowerBank USB-A IQ → Toggle → Router
//
// Part selector: -D 'part="assembly"' / "left" / "center_l" / "center_r" / "right"
// =====================================================================

use <../libs/common.scad>
use <../libs/m4_hardware.scad>

// =====================================================================
// Part Selector (override via CLI: -D 'part="left"')
// =====================================================================
part = "assembly";  // "left" | "center_l" | "center_r" | "right" | "assembly"

$fn = 64;

// =====================================================================
// Structural Parameters
// =====================================================================
wall        = 2.5;      // 4-year-old proof wall thickness
floor_t     = 2.0;      // Floor thickness
fillet_r    = 1.2;      // Fillet radius on ALL external edges
corner_r    = 4.0;      // Corner rounding radius
grip_r      = 8.0;      // Grip edge rounding (ergonomic)

// =====================================================================
// Component Dimensions (exact manufacturer specs)
// =====================================================================

// Samsung Galaxy Tab A 8.0 S Pen (SM-P200)
tablet_w    = 201.5;    // Width (landscape)
tablet_d    = 122.4;    // Depth/height (landscape)
tablet_h    = 8.9;      // Thickness
tablet_clr  = 1.0;      // Clearance per side
tablet_tilt = 15;       // Backward tilt (degrees)
spen_notch_w = 15.0;    // S-Pen slot clearance width
spen_notch_d = 15.0;    // S-Pen slot clearance depth
usbc_cut_w  = 14.0;     // USB-C port cutout width
usbc_cut_h  = 9.0;      // USB-C port cutout height
lip_h       = 3.0;      // Retaining lip height
lip_w       = 1.5;      // Lip overhang width

// PS2 Joystick Module (x2)
joy_w       = 34.0;     // Width
joy_d       = 26.0;     // Depth
joy_h       = 32.0;     // Height (full travel)
joy_clr     = 0.5;      // Clearance per side
joy_shaft_d = 18.0;     // Thumbstick poke-through hole diameter
joy_mount_holes = 28.0; // Diagonal mounting hole spacing

// Sanwa 24mm Snap-in Buttons (x4)
btn_dia     = 24.0;     // Button barrel diameter
btn_clr     = 0.3;      // Snap-in clearance
btn_depth   = 18.0;     // Button body depth below surface
btn_spacing = 30.0;     // Center-to-center spacing in 2x2 grid

// SJ@JX 822B USB Encoder
enc_w       = 95.0;     // Width
enc_d       = 35.0;     // Depth
enc_h       = 10.0;     // Height
enc_clr     = 0.5;      // Clearance per side

// UGREEN Revodok 105 USB-C Hub (replaces UGREEN Revodok 105)
hub_w       = 121.8;    // Width (long axis) — slimmer profile
hub_d       = 27.5;     // Depth
hub_h       = 12.0;     // Height
hub_clr     = 0.5;      // Clearance per side
hub_cable_l = 240;      // Attached USB-C cable length (mm)

// TP-Link Router
router_w    = 57.0;     // Width
router_d    = 57.0;     // Depth
router_h    = 18.0;     // Height
router_clr  = 1.0;      // Clearance per side (side-loading)
router_vent_w = 1.5;    // Ventilation slit width
router_vent_n = 6;      // Number of slits

// Anker PowerCore Slim 10000
pbank_w     = 149.0;    // Width (long axis)
pbank_d     = 68.0;     // Depth
pbank_h     = 14.0;     // Height
pbank_clr   = 0.5;      // Clearance per side

// USB Inline Toggle Switch (Circuit C power control)
usb_sw_w    = 30.0;     // Slot width
usb_sw_d    = 12.0;     // Slot depth
usb_sw_h    = 10.0;     // Slot height

// Cable channels
cable_ch_w  = 8.0;      // Channel width
cable_ch_d  = 6.0;      // Channel depth

// =====================================================================
// Overall Layout Dimensions
// =====================================================================
// Grips are ergonomic extensions on left and right of the tablet center.
// The center section holds the tablet (tilted), powerbank (bottom), hub,
// and router. Grips hold joysticks (top), encoder (left bottom),
// buttons (right top), and USB switch (right bottom).

// Center section width: tablet + clearance + walls
center_w    = tablet_w + 2 * tablet_clr + 2 * wall;  // ~208.5mm

// Grip widths: must fit joystick + wall + ergonomic margin
grip_w      = 40.0;     // Each grip width (~40mm, comfortable for small hands)

// Total width
total_w     = grip_w + center_w + grip_w;  // ~288.5mm

// Total depth (Y): tablet depth projection + bottom bay
// Tablet tilted 15deg: footprint_y = tablet_d*cos(15) + tablet_h*sin(15) ≈ 120.5mm
tablet_footprint_y = tablet_d * cos(tablet_tilt) + tablet_h * sin(tablet_tilt);
bottom_bay_d = max(pbank_d, hub_d, router_d) + 2 * wall + 4;  // ~75mm
total_d     = tablet_footprint_y + bottom_bay_d + wall;  // ~198mm → but we aim for ~145mm

// Revised: stack powerbank under tablet, hub + router behind/below
// Main body depth: max of tablet footprint and (bottom bay components)
body_d      = 145.0;    // Target depth

// Total height: grip height determines this (joystick is tallest at 32mm)
// Top surface to bottom: wall + joy_h + floor = 2.5 + 32 + 2 = 36.5
// Plus bottom bay: pbank 14mm + wall 2mm = 16mm
// Total: ~52mm from top of grip to bottom of powerbank bay
grip_h      = joy_h + joy_clr + wall + floor_t;  // ~37.5mm (grip section)
bottom_h    = pbank_h + pbank_clr + floor_t + wall;  // ~19mm
total_h     = 70.0;     // Total height of center section (tablet tilt adds height)

// =====================================================================
// Split Planes — 4 pieces for 180mm build volume
// =====================================================================
// Split 1: left grip | center-left at x = grip_w
// Split 2: center-left | center-right at x = grip_w + center_w/2
// Split 3: center-right | right grip at x = grip_w + center_w
// Left piece:    grip_w(40) x body_d(145) x total_h(70) — fits
// Center-Left:   center_w/2(104.25) x body_d(145) x total_h(70) — fits
// Center-Right:  center_w/2(104.25) x body_d(145) x total_h(70) — fits
// Right piece:   grip_w(40) x body_d(145) x total_h(70) — fits

split_left_x  = grip_w;                    // Left grip ends here
split_mid_x   = grip_w + center_w / 2;     // Center halves split here
split_right_x = grip_w + center_w;         // Right grip starts here

// M4 bolt joint parameters
bolt_depth  = 12.0;
joint_key_size = 4.0;
joint_key_h = 3.0;

// =====================================================================
// Component Positions (origin at front-bottom-left corner of full body)
// X: left to right, Y: front to back, Z: bottom to top
// =====================================================================

// --- Tablet position ---
// Tablet sits in center section, tilted back 15deg, upper portion
tablet_x = grip_w + wall + tablet_clr;
tablet_y = body_d - wall - 5;   // Near rear, tilted backward
tablet_z = total_h - 20;        // Upper zone (adjusted for tilt)

// --- Powerbank position ---
// Bottom layer, centered under tablet area
pbank_x = grip_w + (center_w - pbank_w) / 2;
pbank_y = wall + 2;
pbank_z = floor_t;

// --- Hub position ---
// Bottom bay, center-left area
hub_x = grip_w + wall + 5;
hub_y = wall + pbank_d + pbank_clr * 2 + 5;
hub_z = floor_t;

// --- Router position ---
// Bottom bay, center-right area, next to hub
router_x = hub_x + hub_w + hub_clr * 2 + 5;
router_y = hub_y;
router_z = floor_t;

// --- Left joystick position ---
// Centered in left grip, near top
ljoy_x = (grip_w - joy_w) / 2;
ljoy_y = (body_d - joy_d) / 2 - 10;  // Slightly forward of center
ljoy_z = total_h - wall - joy_h - joy_clr;

// --- Right joystick position ---
// Upper portion of right grip
rjoy_x = split_right_x + (grip_w - joy_w) / 2;
rjoy_y = ljoy_y;  // Same Y as left
rjoy_z = ljoy_z;

// --- Button positions (right grip) ---
// 2x2 grid below and to the right of right joystick
btn_grid_x = split_right_x + grip_w / 2;  // Center of right grip
btn_grid_y = body_d / 2 + 15;             // Below joystick center
btn_grid_z = total_h - wall;              // Flush with top surface

// --- Encoder position ---
// Under left grip, bottom area
enc_x = (grip_w - enc_w) / 2;
// Encoder is wider than grip — extend into center section
enc_x = wall;  // Flush with left wall
enc_y = body_d - wall - enc_d - enc_clr - 2;
enc_z = floor_t;

// --- USB switch position ---
// Recessed slot on right grip exterior
usb_sw_x = split_right_x + grip_w - wall - 2;
usb_sw_y = body_d - 30;
usb_sw_z = floor_t + 5;


// =====================================================================
// Module: Tablet Slot — 15deg tilted cradle with S-Pen notch
// =====================================================================
module tablet_slot() {
    // Pocket dimensions with clearance
    pw = tablet_w + 2 * tablet_clr;   // ~203.5mm
    pd = tablet_d + 2 * tablet_clr;   // ~124.4mm
    ph = tablet_h + tablet_clr + 2;   // ~11.9mm pocket depth

    // Cradle base: at top-rear of center section, tilted back
    cradle_z = total_h - 25;

    translate([grip_w + wall, body_d - wall - 5, cradle_z])
    rotate([-tablet_tilt, 0, 0]) {
        // Main pocket cutout
        translate([0, -pd, 0])
            cube([pw, pd, ph]);

        // USB-C cutout at bottom edge (centered on tablet width)
        translate([(pw - usbc_cut_w) / 2, -pd - wall - 1, 0])
            cube([usbc_cut_w, wall + 2, usbc_cut_h]);

        // S-Pen notch: bottom-right corner of tablet
        // The S-Pen slides out from the bottom-right edge
        translate([pw - spen_notch_w - tablet_clr, -pd - 1, -1])
            cube([spen_notch_w, spen_notch_d + 1, ph + 2]);
    }
}

// =====================================================================
// Module: Tablet Lips — retaining edges (left, right, top, bottom)
// =====================================================================
module tablet_lips() {
    pw = tablet_w + 2 * tablet_clr;
    pd = tablet_d + 2 * tablet_clr;
    ph = tablet_h + tablet_clr + 2;
    cradle_z = total_h - 25;

    translate([grip_w + wall, body_d - wall - 5, cradle_z])
    rotate([-tablet_tilt, 0, 0])
    translate([0, -pd, ph]) {
        // Left lip
        cube([lip_w, pd, lip_h]);
        // Right lip (leave gap for S-Pen)
        translate([pw - lip_w, spen_notch_d + 5, 0])
            cube([lip_w, pd - spen_notch_d - 5, lip_h]);
        // Bottom lip (front edge) — leave USB-C gap
        usbc_gap_start = (pw - usbc_cut_w) / 2 - 5;
        usbc_gap_end = (pw + usbc_cut_w) / 2 + 5;
        // Left segment
        cube([usbc_gap_start, lip_w, lip_h]);
        // Right segment (leave S-Pen gap)
        translate([usbc_gap_end, 0, 0])
            cube([pw - usbc_gap_end - spen_notch_w - 5, lip_w, lip_h]);
        // Top lip (rear edge)
        translate([0, pd - lip_w, 0])
            cube([pw, lip_w, lip_h]);
    }
}

// =====================================================================
// Module: Tablet Dummy (ghost visualization)
// =====================================================================
module tablet_dummy() {
    pw = tablet_w + 2 * tablet_clr;
    pd = tablet_d + 2 * tablet_clr;
    ph = tablet_h + tablet_clr + 2;
    cradle_z = total_h - 25;

    translate([grip_w + wall + tablet_clr, body_d - wall - 5, cradle_z])
    rotate([-tablet_tilt, 0, 0])
    translate([0, -pd + tablet_clr, 1])
        %cube([tablet_w, tablet_d, tablet_h]);
}

// =====================================================================
// Module: Joystick Mount — PS2 module cavity with thumbstick hole
// =====================================================================
module joystick_mount(x, y, z) {
    // Cavity for PS2 joystick module, open top for thumbstick
    sw = joy_w + 2 * joy_clr;
    sd = joy_d + 2 * joy_clr;
    sh = joy_h + joy_clr;

    translate([x, y, z]) {
        // Joystick cavity (cut from body)
        cube([sw, sd, sh + wall + 10]);

        // Thumbstick poke-through hole (centered, through top surface)
        // Extended +/-5mm to guarantee penetration through rounded grip shell
        translate([sw / 2, sd / 2, sh - 5])
            cylinder(h = wall + 15, d = joy_shaft_d);
    }
}

// =====================================================================
// Module: Joystick Dummy (ghost)
// =====================================================================
module joystick_dummy(x, y, z) {
    translate([x + joy_clr, y + joy_clr, z])
        %cube([joy_w, joy_d, joy_h]);
}

// =====================================================================
// Module: Button Holes — 4x Sanwa 24mm snap-in, 2x2 grid
// =====================================================================
module button_holes() {
    // 2x2 grid centered at btn_grid_x, btn_grid_y
    // Layout:  [A] [B]    (top row)
    //          [X] [Y]    (bottom row)
    for (col = [-0.5, 0.5]) {
        for (row = [-0.5, 0.5]) {
            bx = btn_grid_x + col * btn_spacing;
            by = btn_grid_y + row * btn_spacing;
            // Snap-in hole through top surface
            // Extended +5mm above to guarantee penetration through rounded grip shell
            translate([bx, by, btn_grid_z - btn_depth])
                cylinder(h = btn_depth + wall + 10, d = btn_dia + btn_clr * 2);
        }
    }
}

// =====================================================================
// Module: Button Labels (embossed letters on top surface)
// =====================================================================
module button_labels() {
    labels = ["A", "B", "X", "Y"];
    offsets = [[-0.5, 0.5], [0.5, 0.5], [-0.5, -0.5], [0.5, -0.5]];
    for (i = [0:3]) {
        bx = btn_grid_x + offsets[i][0] * btn_spacing;
        by = btn_grid_y + offsets[i][1] * btn_spacing;
        // Label offset from button center (above the button, on surface)
        translate([bx, by + btn_dia / 2 + 3, total_h - 0.3])
            linear_extrude(height = 0.5)
                text(labels[i], size = 5, halign = "center", valign = "center",
                     font = "Liberation Sans:style=Bold");
    }
}

// =====================================================================
// Module: Encoder Bay — SJ@JX 822B under left grip
// =====================================================================
module encoder_bay() {
    sw = enc_w + 2 * enc_clr;
    sd = enc_d + 2 * enc_clr;
    sh = enc_h + enc_clr;

    translate([enc_x, enc_y, enc_z]) {
        // Cavity
        cube([sw, sd, sh]);

        // USB cable exit hole (rear wall)
        translate([sw / 2 - 6, sd - 1, 1])
            cube([12, wall + 2, 8]);

        // Ribbon cable exit (top, toward joystick)
        translate([sw / 2 - 10, 0, sh - 1])
            cube([20, sd / 2, enc_clr + 2]);

        // Dummy volume
        translate([enc_clr, enc_clr, 0])
            %cube([enc_w, enc_d, enc_h]);
    }
}

// =====================================================================
// Module: Bottom Bay — powerbank, hub, router
// =====================================================================
module bottom_bay() {
    // --- Powerbank cradle ---
    bw = pbank_w + 2 * pbank_clr;
    bd = pbank_d + 2 * pbank_clr;
    bh = pbank_h + pbank_clr;

    translate([pbank_x, pbank_y, pbank_z]) {
        // Cradle walls (U-shape)
        difference() {
            union() {
                // Left wall
                cube([wall, bd, bh]);
                // Right wall
                translate([bw + wall, 0, 0])
                    cube([wall, bd, bh]);
                // Back wall
                translate([0, bd, 0])
                    cube([bw + 2 * wall, wall, bh]);
                // Front wall with LED window gap
                cube([bw + 2 * wall, wall, bh]);
            }
            // LED window
            translate([wall + bw / 2 - 10, -0.1, 2])
                cube([20, wall + 0.2, 4]);
        }
        // Dummy
        translate([wall + pbank_clr, pbank_clr, 0])
            %cube([pbank_w, pbank_d, pbank_h]);
    }
}

// =====================================================================
// Module: Hub Mount — UGREEN Revodok 105 in bottom bay
// =====================================================================
module hub_mount() {
    hw = hub_w + 2 * hub_clr;
    hd = hub_d + 2 * hub_clr;
    hh = hub_h + hub_clr;
    rail_t = 1.5;

    translate([hub_x, hub_y, hub_z]) {
        // Left rail
        cube([rail_t, hd, hh]);
        // Right rail
        translate([hw + rail_t, 0, 0])
            cube([rail_t, hd, hh]);
        // Bottom rail
        cube([hw + 2 * rail_t, hd, rail_t]);
        // Back stop
        translate([0, hd, 0])
            cube([hw + 2 * rail_t, rail_t, hh]);

        // USB-C PD input cutout (front face — toward user)
        // Cut handled in main body difference

        // Dummy
        translate([rail_t + hub_clr, hub_clr, rail_t + 0.5])
            %cube([hub_w, hub_d, hub_h]);
    }
}

// =====================================================================
// Module: Router Slot — TP-Link side-loading with ventilation
// =====================================================================
module router_slot() {
    sw = router_w + 2 * router_clr;
    sd = router_d + 2 * router_clr;
    sh = router_h + 2 * router_clr;

    translate([router_x, router_y, router_z]) {
        difference() {
            // Outer block (walls on 3 sides, open on one for side-loading)
            cube([sw + wall, sd + wall, sh + wall]);

            // Inner cavity — open on +X face for side-loading
            translate([-0.1, wall / 2, wall])
                cube([sw + 0.2, sd, sh]);

            // Ventilation slits on top face
            vent_spacing = (sw - router_vent_n * router_vent_w) / (router_vent_n + 1);
            for (i = [0 : router_vent_n - 1]) {
                vx = vent_spacing + i * (router_vent_w + vent_spacing);
                translate([vx, wall + 3, sh + wall - 0.1])
                    cube([router_vent_w, sd - 6, wall + 0.2]);
            }

            // Ventilation slits on back wall
            for (i = [0 : router_vent_n - 1]) {
                vx = vent_spacing + i * (router_vent_w + vent_spacing);
                translate([vx, sd + wall - 0.1, wall + 2])
                    cube([router_vent_w, wall + 0.2, sh - 4]);
            }

            // Micro-USB power cutout (front face)
            translate([(sw - 12) / 2, -0.1, wall + (sh - 8) / 2])
                cube([12, wall + 0.2, 8]);
        }

        // Dummy
        translate([router_clr, wall / 2 + router_clr, wall + router_clr])
            %cube([router_w, router_d, router_h]);
    }
}

// =====================================================================
// Module: USB Switch Slot — recessed slot on right grip
// =====================================================================
module usb_switch_slot() {
    // Recessed slot for inline USB toggle (Circuit C power control)
    translate([usb_sw_x, usb_sw_y, usb_sw_z])
        cube([wall + 2, usb_sw_d, usb_sw_h]);
}

// =====================================================================
// Module: Cable Routing — Circuit A/B/C separated channels
// =====================================================================
module cable_routing() {
    // Circuit A/B channel: powerbank → hub → tablet USB-C
    // Runs along center-left, from powerbank area up to tablet cradle

    // Horizontal channel: powerbank to hub (along Y)
    ch_ab_x = pbank_x + pbank_w / 2 - cable_ch_w / 2;
    ch_ab_y1 = pbank_y + pbank_d + pbank_clr;
    ch_ab_y2 = hub_y;
    translate([ch_ab_x, ch_ab_y1, floor_t])
        cube([cable_ch_w, ch_ab_y2 - ch_ab_y1, cable_ch_d]);

    // Vertical channel: hub area up to tablet (along Z)
    translate([ch_ab_x, hub_y + hub_d / 2, floor_t])
        cube([cable_ch_w, cable_ch_w, total_h - 25 - floor_t]);

    // Circuit C channel: powerbank USB-A → right side → USB switch → router
    // Runs along RIGHT wall, separated from A/B
    ch_c_x = split_right_x - cable_ch_w - wall - 2;
    translate([ch_c_x, pbank_y + pbank_d / 2, floor_t])
        cube([cable_ch_w, body_d - pbank_y - pbank_d / 2 - wall, cable_ch_d]);

    // Cross channel from router to Circuit C
    translate([router_x, router_y + router_d / 2 - cable_ch_w / 2, floor_t])
        cube([ch_c_x - router_x + cable_ch_w, cable_ch_w, cable_ch_d]);

    // Encoder ribbon channel: encoder bay to left joystick (along Z, left grip)
    translate([enc_x + enc_w / 2 - cable_ch_w / 2, enc_y - 5, enc_z + enc_h])
        cube([cable_ch_w, cable_ch_w, ljoy_z - enc_z - enc_h]);
}

// =====================================================================
// Module: Grip Profile — ergonomic rounded grip cross-section
// =====================================================================
module grip_profile_2d(w, h) {
    // Rounded rectangle for comfortable child grip
    offset(r = grip_r) offset(delta = -grip_r)
        square([w, h]);
}

// =====================================================================
// Module: Main Body Shell (full, before splitting)
// =====================================================================
module body_shell() {
    difference() {
        union() {
            // Center section — rectangular with rounded corners
            translate([grip_w, 0, 0])
                rounded_cube([center_w, body_d, total_h], r = corner_r);

            // Left grip — ergonomic extension
            hull() {
                // Inner face (flush with center)
                translate([grip_w, 0, 0])
                    rounded_cube([1, body_d, total_h], r = corner_r);
                // Outer face (rounded grip shape)
                translate([0, body_d * 0.15, total_h * 0.1])
                    rounded_cube([wall, body_d * 0.7, total_h * 0.85], r = grip_r);
            }

            // Right grip — ergonomic extension (mirror)
            hull() {
                translate([split_right_x - 1, 0, 0])
                    rounded_cube([1, body_d, total_h], r = corner_r);
                translate([total_w - wall, body_d * 0.15, total_h * 0.1])
                    rounded_cube([wall, body_d * 0.7, total_h * 0.85], r = grip_r);
            }
        }

        // Hollow interior — center section
        translate([grip_w + wall, wall, floor_t])
            cube([center_w - 2 * wall, body_d - 2 * wall, total_h]);

        // Hollow interior — left grip
        translate([wall, wall + body_d * 0.15, floor_t + total_h * 0.1])
            cube([grip_w, body_d * 0.7 - wall, total_h * 0.85 - floor_t]);

        // Hollow interior — right grip
        translate([split_right_x, wall, floor_t])
            cube([grip_w - wall, body_d - 2 * wall, total_h - floor_t]);
    }
}

// =====================================================================
// Module: Split Joint Hardware — keys, sockets, M4 bolts
// =====================================================================

// Joint positions along the split seams
joint_y_positions = [body_d * 0.25, body_d * 0.5, body_d * 0.75];
joint_z_positions = [total_h * 0.33, total_h * 0.66];

// --- Left-Center Joint ---
module left_center_keys() {
    // Alignment keys on left piece (protrude +X into center)
    for (jy = joint_y_positions) {
        for (jz = joint_z_positions) {
            translate([split_left_x, jy, jz])
                rotate([0, 90, 0])
                    split_key(size = joint_key_size, height = joint_key_h);
        }
    }
}

module left_center_sockets() {
    // Sockets on center piece (receive keys from left)
    for (jy = joint_y_positions) {
        for (jz = joint_z_positions) {
            translate([split_left_x, jy, jz])
                rotate([0, 90, 0])
                    split_socket(size = joint_key_size, height = joint_key_h);
        }
    }
}

module left_center_bolts() {
    // M4 bolt holes at left-center seam
    bolt_positions = [
        [split_left_x, body_d * 0.3, total_h * 0.5],
        [split_left_x, body_d * 0.7, total_h * 0.5]
    ];
    for (bp = bolt_positions) {
        translate([bp[0] - bolt_depth / 2, bp[1], bp[2]])
            rotate([0, 90, 0])
                m4_hole(depth = bolt_depth);
    }
}

module left_bolt_access() {
    // M4 head access holes through left grip outer wall (X-direction)
    bolt_positions = [
        [split_left_x, body_d * 0.3, total_h * 0.5],
        [split_left_x, body_d * 0.7, total_h * 0.5]
    ];
    for (bp = bolt_positions) {
        translate([-0.1, bp[1], bp[2]])
            rotate([0, 90, 0])
                cylinder(h = split_left_x + 0.2, d = M4_HEAD_DIAMETER + 1);
    }
}

// --- Center-Right Joint ---
module center_right_keys() {
    for (jy = joint_y_positions) {
        for (jz = joint_z_positions) {
            translate([split_right_x, jy, jz])
                rotate([0, 90, 0])
                    split_key(size = joint_key_size, height = joint_key_h);
        }
    }
}

module center_right_sockets() {
    for (jy = joint_y_positions) {
        for (jz = joint_z_positions) {
            translate([split_right_x, jy, jz])
                rotate([0, 90, 0])
                    split_socket(size = joint_key_size, height = joint_key_h);
        }
    }
}

module center_right_bolts() {
    bolt_positions = [
        [split_right_x, body_d * 0.3, total_h * 0.5],
        [split_right_x, body_d * 0.7, total_h * 0.5]
    ];
    for (bp = bolt_positions) {
        translate([bp[0] - bolt_depth / 2, bp[1], bp[2]])
            rotate([0, 90, 0])
                m4_hole(depth = bolt_depth);
    }
}

module right_bolt_access() {
    // M4 head access holes through right grip outer wall (X-direction)
    bolt_positions = [
        [split_right_x, body_d * 0.3, total_h * 0.5],
        [split_right_x, body_d * 0.7, total_h * 0.5]
    ];
    for (bp = bolt_positions) {
        translate([split_right_x - 0.1, bp[1], bp[2]])
            rotate([0, 90, 0])
                cylinder(h = grip_w + 0.2, d = M4_HEAD_DIAMETER + 1);
    }
}

// --- Center-Mid Joint (between center-left and center-right) ---
module center_mid_keys() {
    for (jy = joint_y_positions) {
        for (jz = joint_z_positions) {
            translate([split_mid_x, jy, jz])
                rotate([0, 90, 0])
                    split_key(size = joint_key_size, height = joint_key_h);
        }
    }
}

module center_mid_sockets() {
    for (jy = joint_y_positions) {
        for (jz = joint_z_positions) {
            translate([split_mid_x, jy, jz])
                rotate([0, 90, 0])
                    split_socket(size = joint_key_size, height = joint_key_h);
        }
    }
}

module center_mid_bolts() {
    bolt_positions = [
        [split_mid_x, body_d * 0.3, total_h * 0.5],
        [split_mid_x, body_d * 0.7, total_h * 0.5]
    ];
    for (bp = bolt_positions) {
        translate([bp[0] - bolt_depth / 2, bp[1], bp[2]])
            rotate([0, 90, 0])
                m4_hole(depth = bolt_depth);
    }
}

// =====================================================================
// Module: Left Grip — joystick + encoder
// =====================================================================
module left_grip() {
    difference() {
        union() {
            // Left portion of body shell
            intersection() {
                cube([split_left_x + 0.01, body_d + 1, total_h + 50]);
                body_shell();
            }
            // Alignment keys (protrude into center)
            left_center_keys();
        }

        // Left joystick cavity
        joystick_mount(ljoy_x, ljoy_y, ljoy_z);

        // Encoder bay
        encoder_bay();

        // Cable routing (left portion)
        intersection() {
            cube([split_left_x + 0.1, body_d + 1, total_h + 1]);
            cable_routing();
        }

        // M4 bolt holes at seam
        left_center_bolts();

        // Bolt head access through outer wall
        left_bolt_access();

        // Fillet approximation: chamfer bottom edges
        translate([-0.1, -0.1, -0.1])
            rotate([0, 90, 0])
                linear_extrude(height = split_left_x + 0.2)
                    polygon([[0, 0], [-fillet_r, 0], [0, fillet_r]]);
    }

    // Ghost volumes
    joystick_dummy(ljoy_x, ljoy_y, ljoy_z);
}

// =====================================================================
// Module: Right Grip — joystick + buttons + USB switch
// =====================================================================
module right_grip() {
    // Local origin shifted so seam face is at x=0
    translate([-split_right_x, 0, 0])
    difference() {
        union() {
            // Right portion of body shell
            intersection() {
                translate([split_right_x - 0.01, 0, 0])
                    cube([grip_w + 0.02, body_d + 1, total_h + 50]);
                body_shell();
            }
        }

        // Alignment sockets (receive keys from center)
        center_right_sockets();

        // Right joystick cavity
        joystick_mount(rjoy_x, rjoy_y, rjoy_z);

        // Button holes (4x Sanwa 24mm)
        button_holes();

        // USB switch slot
        usb_switch_slot();

        // Cable routing (right portion)
        intersection() {
            translate([split_right_x - 0.1, 0, 0])
                cube([grip_w + 0.2, body_d + 1, total_h + 1]);
            cable_routing();
        }

        // M4 bolt holes at seam
        center_right_bolts();

        // Bolt head access through outer wall
        right_bolt_access();
    }

    // Ghost volumes and labels
    translate([-split_right_x, 0, 0]) {
        joystick_dummy(rjoy_x, rjoy_y, rjoy_z);
        button_labels();
    }
}

// =====================================================================
// Module: Center body ventilation — through outer walls to open air
// =====================================================================
module center_ventilation() {
    vent_w = 1.5;
    vent_n = 8;

    // Bottom vents under powerbank area (through floor to open air)
    pbank_vent_start = pbank_x + 10;
    pbank_vent_spacing = (pbank_w - 20) / (vent_n + 1);
    for (i = [0 : vent_n - 1]) {
        translate([pbank_vent_start + i * pbank_vent_spacing,
                   pbank_y + 5, -0.1])
            cube([vent_w, pbank_d - 10, floor_t + 0.2]);
    }

    // Bottom vents under router area (through floor to open air)
    router_vent_start = router_x + 5;
    router_vent_sp = (router_w - 10) / 5;
    for (i = [0 : 4]) {
        translate([router_vent_start + i * router_vent_sp,
                   router_y + 5, -0.1])
            cube([vent_w, router_d - 10, floor_t + 0.2]);
    }

    // Rear wall vents behind router (through body rear wall to open air)
    for (i = [0 : 4]) {
        translate([router_x + 5 + i * 10,
                   body_d - wall - 0.1, router_z + wall + 2])
            cube([vent_w, wall + 0.2, router_h - 4]);
    }

    // Bottom vents under hub area (through floor to open air)
    hub_vent_start = hub_x + 5;
    hub_vent_sp = (hub_w - 10) / (vent_n + 1);
    for (i = [0 : vent_n - 1]) {
        translate([hub_vent_start + i * hub_vent_sp,
                   hub_y + 3, -0.1])
            cube([vent_w, hub_d - 6, floor_t + 0.2]);
    }
}

// =====================================================================
// Module: Center-Left Section — left half of center (tablet left + powerbank + hub)
// =====================================================================
module center_left_section() {
    translate([-split_left_x, 0, 0])
    difference() {
        union() {
            intersection() {
                translate([split_left_x - 0.01, 0, 0])
                    cube([center_w / 2 + 0.02, body_d + 1, total_h + 50]);
                union() {
                    body_shell();
                    tablet_lips();
                }
            }

            intersection() {
                translate([split_left_x - 0.01, 0, 0])
                    cube([center_w / 2 + 0.02, body_d + 1, total_h + 1]);
                union() {
                    hub_mount();
                    router_slot();
                }
            }

            center_mid_keys();
        }

        left_center_sockets();

        tablet_slot();

        translate([pbank_x + wall, pbank_y, pbank_z])
            cube([pbank_w + 2 * pbank_clr, pbank_d + 2 * pbank_clr,
                  pbank_h + pbank_clr]);

        intersection() {
            translate([split_left_x - 0.1, 0, 0])
                cube([center_w / 2 + 0.2, body_d + 1, total_h + 1]);
            cable_routing();
        }

        // Hub port cutout (USB-C PD input on front face)
        translate([hub_x + hub_w / 2 - 7, -0.1, hub_z + 2])
            cube([14, wall + 0.2, 10]);

        // Hub USB-A port cutouts (rear or side)
        translate([hub_x + hub_w / 2 - 20, hub_y + hub_d + hub_clr, hub_z + 2])
            cube([40, wall + 0.2, 10]);

        left_center_bolts();
        center_mid_bolts();

        // Powerbank port cutouts
        translate([pbank_x + pbank_w / 2 - 7, -0.1, pbank_z + 2])
            cube([14, wall + 0.2, 8]);
        translate([pbank_x + pbank_w / 2 + 15, -0.1, pbank_z + 2])
            cube([14, wall + 0.2, 8]);

        // LED indicator window
        translate([pbank_x + pbank_w / 2 - 10, -0.1, pbank_z + pbank_h - 2])
            cube([20, wall + 0.2, 4]);

        center_ventilation();
    }

    translate([-split_left_x, 0, 0]) {
        tablet_dummy();

        translate([pbank_x + wall + pbank_clr, pbank_y + pbank_clr, pbank_z])
            %cube([pbank_w, pbank_d, pbank_h]);
    }
}

// =====================================================================
// Module: Center-Right Section — right half of center (tablet right + router)
// =====================================================================
module center_right_section() {
    translate([-split_mid_x, 0, 0])
    difference() {
        union() {
            intersection() {
                translate([split_mid_x - 0.01, 0, 0])
                    cube([center_w / 2 + 0.02, body_d + 1, total_h + 50]);
                union() {
                    body_shell();
                    tablet_lips();
                }
            }

            intersection() {
                translate([split_mid_x - 0.01, 0, 0])
                    cube([center_w / 2 + 0.02, body_d + 1, total_h + 1]);
                union() {
                    hub_mount();
                    router_slot();
                }
            }

            center_right_keys();
        }

        center_mid_sockets();

        tablet_slot();

        translate([pbank_x + wall, pbank_y, pbank_z])
            cube([pbank_w + 2 * pbank_clr, pbank_d + 2 * pbank_clr,
                  pbank_h + pbank_clr]);

        intersection() {
            translate([split_mid_x - 0.1, 0, 0])
                cube([center_w / 2 + 0.2, body_d + 1, total_h + 1]);
            cable_routing();
        }

        // Router port cutout through body wall
        translate([router_x + router_w / 2 - 6,  -0.1, router_z + wall + 3])
            cube([12, wall + 0.2, 8]);

        center_mid_bolts();
        center_right_bolts();

        center_ventilation();
    }
}

// =====================================================================
// Module: Cradle Left — printable left grip piece
// =====================================================================
module cradle_left() {
    left_grip();
}

// =====================================================================
// Module: Cradle Center Left — printable center-left piece
// =====================================================================
module cradle_center_left() {
    center_left_section();
}

// =====================================================================
// Module: Cradle Center Right — printable center-right piece
// =====================================================================
module cradle_center_right() {
    center_right_section();
}

// =====================================================================
// Module: Cradle Right — printable right grip piece
// =====================================================================
module cradle_right() {
    right_grip();
}

// =====================================================================
// Module: Cradle Assembly — all four pieces joined
// =====================================================================
module cradle_assembly() {
    cradle_left();
    translate([split_left_x, 0, 0])
        cradle_center_left();
    translate([split_mid_x, 0, 0])
        cradle_center_right();
    translate([split_right_x, 0, 0])
        cradle_right();
}

// =====================================================================
// Render Selected Part
// =====================================================================
if (part == "left")            cradle_left();
else if (part == "center_l")   cradle_center_left();
else if (part == "center_r")   cradle_center_right();
else if (part == "right")      cradle_right();
else if (part == "assembly")   cradle_assembly();

// =====================================================================
// Debug: Print computed dimensions
// =====================================================================
echo(str("=== Handheld Gamepad Console (4-piece split) ==="));
echo(str("Total size: ", total_w, " x ", body_d, " x ", total_h, " mm"));
echo(str("Left grip piece: ", split_left_x, " x ", body_d, " x ", total_h, " mm"));
echo(str("Center-Left piece: ", center_w / 2, " x ", body_d, " x ", total_h, " mm"));
echo(str("Center-Right piece: ", center_w / 2, " x ", body_d, " x ", total_h, " mm"));
echo(str("Right grip piece: ", grip_w, " x ", body_d, " x ", total_h, " mm"));
echo(str("Split Left X: ", split_left_x));
echo(str("Split Mid X: ", split_mid_x));
echo(str("Split Right X: ", split_right_x));
echo(str("Tablet pos: [", tablet_x, ", ", tablet_y, ", ", tablet_z, "]"));
echo(str("PowerBank pos: [", pbank_x, ", ", pbank_y, ", ", pbank_z, "]"));
echo(str("Hub pos: [", hub_x, ", ", hub_y, ", ", hub_z, "]"));
echo(str("Router pos: [", router_x, ", ", router_y, ", ", router_z, "]"));
echo(str("L-Joy pos: [", ljoy_x, ", ", ljoy_y, ", ", ljoy_z, "]"));
echo(str("R-Joy pos: [", rjoy_x, ", ", rjoy_y, ", ", rjoy_z, "]"));
echo(str("Encoder pos: [", enc_x, ", ", enc_y, ", ", enc_z, "]"));
echo(str("Button grid center: [", btn_grid_x, ", ", btn_grid_y, "]"));
