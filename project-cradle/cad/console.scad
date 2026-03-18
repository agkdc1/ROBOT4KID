// =============================================================
// Universal Command Console — Step 2 Blockout
// =============================================================
// Primitives only. No fillets, chamfers, or greebling.
// All dimensions in mm. $fn=32 for circles.
//
// Print pieces (fits 180x180x180mm build volume):
//   1. base_left    — left half of base plate
//   2. base_right   — right half of base plate
//   3. deck_left    — arcade joystick mount
//   4. deck_right   — flight stick mount + button holes
//   5. rear         — rear cover (ethernet, power switch)
//
// Part selector: set `part` to render individual pieces.
// =============================================================

/* [Part Selector] */
part = "assembly"; // [assembly, base_left, base_right, deck_left, deck_right, rear, exploded]

/* [Rendering] */
$fn = 32;

// ----- Structural Parameters -----
wall    = 3.0;   // wall thickness (sturdy desk console)
floor_t = 2.5;   // floor thickness
m3_hole = 3.4;   // M3 through-hole diameter
m25_hole = 2.9;  // M2.5 through-hole diameter
wire_ch = 8;     // wire channel width

// ----- Overall Envelope -----
// Console body (without display): ~400 x 250 x 100mm
console_w = 400;  // total width (X)
console_d = 250;  // total depth (Y)
base_h    = 30;   // base plate height (Z)
deck_h    = 100;  // control deck height (Z, above base)
rear_h    = 80;   // rear cover height (Z)
rear_d    = 40;   // rear cover depth (Y)

// Split line for left/right at center X
split_x = console_w / 2;  // 200mm

// ----- Component Dimensions -----
// RPi 4B + heatsink
rpi_w = 85;   rpi_d = 56;   rpi_h = 47;  // includes 30mm heatsink
rpi_mount_x = 58;  rpi_mount_y = 49;      // M2.5 hole spacing

// 7" Display (sits on own legs above console)
disp_w = 194;  disp_d = 110;  disp_h = 20;
disp_leg_h = 15;  // approximate height of display legs

// Anker PowerCore Slim 10000
pwr_w = 149;  pwr_d = 68;  pwr_h = 14;

// USB Encoder board
enc_w = 95;  enc_d = 35;  enc_h = 10;

// Arcade Joystick (left)
aj_plate  = 95;      // mounting plate is square
aj_below  = 60;      // mechanism depth below deck
aj_above  = 40;      // shaft + ball-top above deck
aj_shaft  = 25;      // shaft hole diameter

// Flight Stick (right)
fs_plate  = 90;      // mounting plate square-ish
fs_below  = 80;      // mechanism depth below deck
fs_above  = 50;      // shaft + trigger housing above deck
fs_shaft  = 30;      // shaft hole diameter

// Arcade Buttons (30mm snap-in)
btn_dia   = 30;      // button diameter
btn_space = 40;      // center-to-center spacing in 2x2 grid

// iUniker power switch
sw_w = 80;  sw_d = 40;  sw_h = 20;

// Ethernet panel mount cutout
eth_w = 22;  eth_h = 16;

// ----- Derived Positions -----
// Base plate is the bottom layer: holds RPi, encoder, power bank
// Base occupies Y from 0 to console_d, X from 0 to console_w

// RPi sits center-ish in the base, behind the deck area
rpi_x = split_x - rpi_w/2;          // centered on split line
rpi_y = console_d - rear_d - rpi_d - 10;  // in front of rear cover

// Encoder sits left of RPi
enc_x = 10;
enc_y = rpi_y + (rpi_d - enc_d)/2;  // vertically aligned with RPi

// Power bank sits right of RPi
pwr_x = console_w - pwr_w - 10;
pwr_y = rpi_y + (rpi_d - pwr_d)/2;

// Deck occupies front portion of console
deck_d = 130;  // depth of deck area
deck_y = 0;    // starts at front edge

// Left deck: arcade joystick — centered in left third
deck_left_w = 130;
deck_left_x = 0;
aj_cx = deck_left_x + deck_left_w/2;   // joystick center X
aj_cy = deck_y + deck_d/2;              // joystick center Y

// Right deck: flight stick — centered in right portion
deck_right_w = 130;
deck_right_x = console_w - deck_right_w;
fs_cx = deck_right_x + deck_right_w/2;  // flight stick center X
fs_cy = deck_y + deck_d/2;              // flight stick center Y

// Buttons: 2x2 diagonal grid in center zone (between joystick and flight stick)
btn_cx = console_w/2;                    // button group center X
btn_cy = deck_y + deck_d/2;             // button group center Y

// Display sits on top surface behind the deck, on its own legs
disp_x = (console_w - disp_w) / 2;
disp_y = console_d - rear_d - disp_d + 20;  // overlaps rear area slightly
disp_z = base_h;  // sits on top of base plate surface

// Power switch on rear panel, right side
sw_x = console_w - sw_w - 20;
sw_y = console_d - rear_d;
sw_z = floor_t + 10;

// Ethernet cutout on rear panel, left-center
eth_x = split_x - eth_w/2 - 40;
eth_z = floor_t + 30;


// =============================================================
// MODULE: M3 bolt hole (vertical, for joining pieces)
// =============================================================
module m3_bolt_hole(depth=15) {
    cylinder(d=m3_hole, h=depth, center=true);
}

// =============================================================
// MODULE: M2.5 standoff hole (for RPi mounting)
// =============================================================
module m25_standoff(h=8) {
    // Boss with hole
    difference() {
        cylinder(d=6, h=h);
        translate([0, 0, -0.1])
            cylinder(d=m25_hole, h=h+0.2);
    }
}

// =============================================================
// MODULE: Wire channel (routed along bottom)
// =============================================================
module wire_channel(length) {
    cube([wire_ch, length, wire_ch]);
}

// =============================================================
// MODULE: base_left — Left half of base plate
// Holds: encoder bay, left portion of RPi area
// =============================================================
module base_left() {
    difference() {
        // Outer shell — left half
        cube([split_x, console_d - rear_d, base_h]);

        // Hollow interior (leave walls and floor)
        translate([wall, wall, floor_t])
            cube([split_x - wall*2, console_d - rear_d - wall*2, base_h]);

        // Joint bolt holes along split seam (right edge)
        for (y = [30, console_d/2 - rear_d/2, console_d - rear_d - 30])
            translate([split_x, y, base_h/2])
                rotate([0, 90, 0])
                    m3_bolt_hole(20);

        // Joint bolt holes along top edge (for deck attachment)
        for (x = [30, split_x - 30])
            translate([x, deck_d - 10, base_h])
                m3_bolt_hole(20);

        // Joint bolt holes along rear edge (for rear cover)
        for (x = [30, split_x - 30])
            translate([x, console_d - rear_d, base_h/2])
                rotate([90, 0, 0])
                    m3_bolt_hole(20);
    }

    // Encoder bay cradle (raised edges to hold encoder board)
    if (enc_x + enc_w <= split_x) {
        translate([enc_x, enc_y, floor_t]) {
            // Cradle lips
            cube([enc_w, wall, enc_h + 2]);                       // front lip
            translate([0, enc_d - wall, 0])
                cube([enc_w, wall, enc_h + 2]);                   // rear lip
            cube([wall, enc_d, enc_h + 2]);                       // left lip
            translate([enc_w - wall, 0, 0])
                cube([wall, enc_d, enc_h + 2]);                   // right lip
        }
    }

    // RPi M2.5 standoffs (only those on the left half)
    for (dx = [0, rpi_mount_x])
        for (dy = [0, rpi_mount_y]) {
            sx = rpi_x + (rpi_w - rpi_mount_x)/2 + dx;
            sy = rpi_y + (rpi_d - rpi_mount_y)/2 + dy;
            if (sx < split_x)
                translate([sx, sy, floor_t])
                    m25_standoff(8);
        }

    // Wire channel along left wall bottom
    translate([wall, wall, floor_t])
        wire_channel(console_d - rear_d - wall*2);
}

// =============================================================
// MODULE: base_right — Right half of base plate
// Holds: power bank cradle, right portion of RPi area
// =============================================================
module base_right() {
    difference() {
        // Outer shell — right half
        translate([split_x, 0, 0])
            cube([split_x, console_d - rear_d, base_h]);

        // Hollow interior
        translate([split_x + wall, wall, floor_t])
            cube([split_x - wall*2, console_d - rear_d - wall*2, base_h]);

        // Joint bolt holes along split seam (left edge)
        for (y = [30, console_d/2 - rear_d/2, console_d - rear_d - 30])
            translate([split_x, y, base_h/2])
                rotate([0, 90, 0])
                    m3_bolt_hole(20);

        // Joint bolt holes along top edge (for deck attachment)
        for (x = [split_x + 30, console_w - 30])
            translate([x, deck_d - 10, base_h])
                m3_bolt_hole(20);

        // Joint bolt holes along rear edge (for rear cover)
        for (x = [split_x + 30, console_w - 30])
            translate([x, console_d - rear_d, base_h/2])
                rotate([90, 0, 0])
                    m3_bolt_hole(20);
    }

    // Power bank cradle
    translate([pwr_x, pwr_y, floor_t]) {
        cube([pwr_w, wall, pwr_h + 2]);                         // front lip
        translate([0, pwr_d - wall, 0])
            cube([pwr_w, wall, pwr_h + 2]);                     // rear lip
        cube([wall, pwr_d, pwr_h + 2]);                         // left lip
        translate([pwr_w - wall, 0, 0])
            cube([wall, pwr_d, pwr_h + 2]);                     // right lip
    }

    // RPi M2.5 standoffs (only those on the right half)
    for (dx = [0, rpi_mount_x])
        for (dy = [0, rpi_mount_y]) {
            sx = rpi_x + (rpi_w - rpi_mount_x)/2 + dx;
            sy = rpi_y + (rpi_d - rpi_mount_y)/2 + dy;
            if (sx >= split_x)
                translate([sx, sy, floor_t])
                    m25_standoff(8);
        }

    // Wire channel along right wall bottom
    translate([console_w - wall - wire_ch, wall, floor_t])
        wire_channel(console_d - rear_d - wall*2);
}

// =============================================================
// MODULE: control_deck_left — Arcade joystick area
// Sits on top of base_left at the front
// =============================================================
module control_deck_left() {
    difference() {
        // Outer box
        translate([deck_left_x, deck_y, base_h])
            cube([deck_left_w, deck_d, deck_h]);

        // Hollow interior (mechanism cavity below deck surface)
        translate([deck_left_x + wall, deck_y + wall, base_h + floor_t])
            cube([deck_left_w - wall*2, deck_d - wall*2, deck_h - wall]);

        // Joystick shaft hole through top surface
        translate([aj_cx, aj_cy, base_h + deck_h - wall - 0.1])
            cylinder(d=aj_shaft, h=wall + 0.2);

        // Mounting plate screw holes (4 corners of 95mm square)
        for (dx = [-aj_plate/2 + 10, aj_plate/2 - 10])
            for (dy = [-aj_plate/2 + 10, aj_plate/2 - 10])
                translate([aj_cx + dx, aj_cy + dy, base_h + deck_h - wall - 0.1])
                    cylinder(d=m3_hole, h=wall + 0.2);

        // Bottom bolt holes to attach to base plate
        for (x = [deck_left_x + 30])
            translate([x, deck_d - 10, base_h])
                m3_bolt_hole(20);

        // Side bolt holes to join with deck_right
        for (z = [base_h + 30, base_h + deck_h - 20])
            translate([deck_left_x + deck_left_w, deck_d/2, z])
                rotate([0, 90, 0])
                    m3_bolt_hole(20);
    }
}

// =============================================================
// MODULE: control_deck_right — Flight stick + 4 arcade buttons
// Sits on top of base_right at the front
// =============================================================
module control_deck_right() {
    // This deck spans from the button zone to the right edge
    dr_x = deck_left_w;  // starts where left deck ends
    dr_w = console_w - deck_left_w;

    difference() {
        // Outer box
        translate([dr_x, deck_y, base_h])
            cube([dr_w, deck_d, deck_h]);

        // Hollow interior
        translate([dr_x + wall, deck_y + wall, base_h + floor_t])
            cube([dr_w - wall*2, deck_d - wall*2, deck_h - wall]);

        // Flight stick shaft hole through top
        translate([fs_cx, fs_cy, base_h + deck_h - wall - 0.1])
            cylinder(d=fs_shaft, h=wall + 0.2);

        // Flight stick mounting plate screw holes
        for (dx = [-fs_plate/2 + 10, fs_plate/2 - 10])
            for (dy = [-fs_plate/2 + 10, fs_plate/2 - 10])
                translate([fs_cx + dx, fs_cy + dy, base_h + deck_h - wall - 0.1])
                    cylinder(d=m3_hole, h=wall + 0.2);

        // 4x 30mm arcade button holes — 2x2 diagonal grid
        // Offset diagonally so row 2 is shifted by half spacing
        for (r = [0, 1])
            for (c = [0, 1])
                translate([
                    btn_cx + (c - 0.5) * btn_space + r * (btn_space * 0.3),
                    btn_cy + (r - 0.5) * btn_space,
                    base_h + deck_h - wall - 0.1
                ])
                    cylinder(d=btn_dia, h=wall + 0.2);

        // Bottom bolt holes to attach to base plate
        for (x = [dr_x + 30, console_w - 30])
            translate([x, deck_d - 10, base_h])
                m3_bolt_hole(20);

        // Side bolt holes to join with deck_left
        for (z = [base_h + 30, base_h + deck_h - 20])
            translate([dr_x, deck_d/2, z])
                rotate([0, 90, 0])
                    m3_bolt_hole(20);
    }
}

// =============================================================
// MODULE: rear_cover — Rear panel with cutouts
// Holds: Ethernet panel mount, power switch slot, cable exits
// =============================================================
module rear_cover() {
    difference() {
        // Outer shell
        translate([0, console_d - rear_d, 0])
            cube([console_w, rear_d, rear_h]);

        // Hollow interior
        translate([wall, console_d - rear_d + wall, floor_t])
            cube([console_w - wall*2, rear_d - wall*2, rear_h - wall]);

        // Ethernet panel mount cutout (rear face)
        translate([eth_x, console_d - 0.1, eth_z])
            cube([eth_w, wall + 0.2, eth_h]);

        // Power switch slot (rear face, right side)
        translate([sw_x, console_d - 0.1, sw_z])
            cube([sw_w, wall + 0.2, sw_h]);

        // Cable exit holes (bottom rear, 3 oval slots)
        for (x = [80, split_x, console_w - 80])
            translate([x, console_d - 0.1, floor_t + 5])
                cube([15, wall + 0.2, 8]);

        // USB port access hole (for RPi USB ports, rear face)
        translate([split_x - 30, console_d - 0.1, floor_t + 10])
            cube([60, wall + 0.2, 15]);

        // Bolt holes to attach to base plates (front face of rear cover)
        for (x = [30, split_x - 30, split_x + 30, console_w - 30])
            translate([x, console_d - rear_d, base_h/2])
                rotate([90, 0, 0])
                    m3_bolt_hole(20);
    }
}

// =============================================================
// MODULE: display_dummy — 7" display ghost volume (not printed)
// For visualization in assembly view only
// =============================================================
module display_dummy() {
    color("DarkSlateGray", 0.5)
        translate([disp_x, disp_y, disp_z + disp_leg_h])
            cube([disp_w, disp_d, disp_h]);

    // Leg indicators
    color("Gray", 0.3)
        for (dx = [20, disp_w - 20])
            translate([disp_x + dx - 2, disp_y + 10, disp_z])
                cube([4, 4, disp_leg_h]);
}

// =============================================================
// MODULE: component_dummies — Ghost volumes for all components
// For visualization in assembly view only
// =============================================================
module component_dummies() {
    // RPi 4B + heatsink
    color("Green", 0.4)
        translate([rpi_x, rpi_y, floor_t + 8])  // on standoffs
            cube([rpi_w, rpi_d, rpi_h]);

    // Encoder board
    color("Blue", 0.4)
        translate([enc_x, enc_y, floor_t])
            cube([enc_w, enc_d, enc_h]);

    // Power bank
    color("DarkBlue", 0.4)
        translate([pwr_x, pwr_y, floor_t])
            cube([pwr_w, pwr_d, pwr_h]);

    // Arcade joystick (shaft + ball-top above deck)
    color("Red", 0.4) {
        translate([aj_cx, aj_cy, base_h + deck_h])
            cylinder(d=15, h=aj_above - 15);
        translate([aj_cx, aj_cy, base_h + deck_h + aj_above - 15])
            sphere(d=30);  // ball-top
    }

    // Arcade joystick mechanism (below deck)
    color("Red", 0.2)
        translate([aj_cx - aj_plate/2, aj_cy - aj_plate/2, base_h + deck_h - aj_below])
            cube([aj_plate, aj_plate, aj_below]);

    // Flight stick (above deck)
    color("Orange", 0.4)
        translate([fs_cx, fs_cy, base_h + deck_h])
            cylinder(d=20, h=fs_above);

    // Flight stick mechanism (below deck)
    color("Orange", 0.2)
        translate([fs_cx - fs_plate/2, fs_cy - fs_plate/2, base_h + deck_h - fs_below])
            cube([fs_plate, fs_plate, fs_below]);

    // 4x Arcade buttons (above deck surface)
    color("Yellow", 0.5)
        for (r = [0, 1])
            for (c = [0, 1])
                translate([
                    btn_cx + (c - 0.5) * btn_space + r * (btn_space * 0.3),
                    btn_cy + (r - 0.5) * btn_space,
                    base_h + deck_h
                ])
                    cylinder(d=btn_dia - 2, h=5);

    // Power switch (on rear panel)
    color("White", 0.4)
        translate([sw_x, console_d - wall, sw_z])
            cube([sw_w, wall + 5, sw_h]);

    // Display
    display_dummy();
}

// =============================================================
// MODULE: console_assembly — All pieces together
// =============================================================
module console_assembly() {
    color("SlateGray", 0.8) {
        base_left();
        base_right();
        control_deck_left();
        control_deck_right();
        rear_cover();
    }
    component_dummies();
}

// =============================================================
// MODULE: exploded_assembly — Pieces separated for clarity
// =============================================================
module exploded_assembly() {
    explode = 30;  // gap between pieces

    color("SlateGray", 0.8) {
        translate([-explode, 0, -explode])
            base_left();
        translate([explode, 0, -explode])
            base_right();
        translate([-explode, -explode, explode])
            control_deck_left();
        translate([explode, -explode, explode])
            control_deck_right();
        translate([0, explode, 0])
            rear_cover();
    }
    translate([0, 0, explode * 2])
        component_dummies();
}

// =============================================================
// PART SELECTOR — Render based on `part` variable
// =============================================================
if (part == "assembly") {
    console_assembly();
} else if (part == "exploded") {
    exploded_assembly();
} else if (part == "base_left") {
    base_left();
} else if (part == "base_right") {
    base_right();
} else if (part == "deck_left") {
    control_deck_left();
} else if (part == "deck_right") {
    control_deck_right();
} else if (part == "rear") {
    rear_cover();
} else {
    echo("ERROR: Unknown part. Use: assembly, exploded, base_left, base_right, deck_left, deck_right, rear");
    console_assembly();
}
