// M3 / M2.5 Hardware Library for Electronics Mounting
// Optimized for Bambu Lab A1 Mini with PLA
// Used for PCB standoffs and component mounting

// --- M3 Dimensions ---
M3_DIAMETER = 3.0;
M3_HEAD_DIAMETER = 5.5;
M3_HEAD_HEIGHT = 2.0;
M3_HOLE_DIA = 3.4;              // Through-hole with clearance
M3_SHAFT_DIA = 2.8;             // For printed screw shaft
M3_NUT_WIDTH = 5.5;             // Across flats
M3_NUT_HEIGHT = 2.4;

// --- M2.5 Dimensions ---
M25_DIAMETER = 2.5;
M25_HEAD_DIAMETER = 4.5;
M25_HEAD_HEIGHT = 1.7;
M25_HOLE_DIA = 2.9;             // Through-hole with clearance
M25_NUT_WIDTH = 5.0;
M25_NUT_HEIGHT = 2.0;

// --- Print Tolerances ---
PRINT_TOL = 0.2;

$fn = 64;

// --- M3 Modules ---

module m3_hole(depth=10) {
    cylinder(h=depth + 0.1, d=M3_HOLE_DIA);
}

module m3_countersink(depth=10) {
    union() {
        cylinder(h=depth + 0.1, d=M3_HOLE_DIA);
        translate([0, 0, depth - M3_HEAD_HEIGHT])
            cylinder(h=M3_HEAD_HEIGHT + 0.1, d=M3_HEAD_DIAMETER + PRINT_TOL);
    }
}

module m3_nut_trap(depth=2.4) {
    cylinder(h=depth + 0.1, d=M3_NUT_WIDTH / cos(30) + PRINT_TOL, $fn=6);
}

module m3_standoff(height=8, outer_dia=6) {
    difference() {
        cylinder(h=height, d=outer_dia);
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=M3_HOLE_DIA);
    }
}

module m3_pcb_standoff(height=8) {
    // Standard PCB standoff with M3 hole
    m3_standoff(height=height, outer_dia=6);
}

// --- M2.5 Modules ---

module m25_hole(depth=10) {
    cylinder(h=depth + 0.1, d=M25_HOLE_DIA);
}

module m25_standoff(height=8, outer_dia=5.5) {
    difference() {
        cylinder(h=height, d=outer_dia);
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=M25_HOLE_DIA);
    }
}

// --- Bolt Patterns ---

module m3_bolt_pattern_rect(dx, dy) {
    // 4-corner bolt pattern
    for (x = [-dx/2, dx/2])
        for (y = [-dy/2, dy/2])
            translate([x, y, 0])
                children();
}

// --- Zip-Tie Point ---

module zip_tie_slot(width=4, thickness=2, depth=3) {
    // Slot for cable zip-tie routing
    translate([-width/2, -thickness/2, 0])
        cube([width, thickness, depth]);
}

// --- Wire Channel ---

module wire_channel(length, width=8, depth=5) {
    // Open-top channel for routing jumper wires
    translate([-width/2, 0, 0])
        cube([width, length, depth]);
}
