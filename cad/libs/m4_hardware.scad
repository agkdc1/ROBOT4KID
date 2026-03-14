// M4 Hardware Library for 3D Printing
// Optimized for Bambu Lab A1 Mini with PLA
// M4 screw: 4mm nominal diameter, 0.7mm pitch

// --- Dimensions ---
M4_DIAMETER = 4.0;
M4_PITCH = 0.7;
M4_HEAD_DIAMETER = 7.0;
M4_HEAD_HEIGHT = 2.8;

// --- Print Tolerances ---
PRINT_TOLERANCE = 0.2;       // General tolerance
HOLE_CLEARANCE = 0.4;        // Extra clearance for through-holes
THREAD_SHRINK = 0.2;         // Shrink screw shaft for stronger print

// --- Derived Dimensions ---
M4_HOLE_DIA = M4_DIAMETER + HOLE_CLEARANCE;        // 4.4mm through-hole
M4_SHAFT_DIA = M4_DIAMETER - THREAD_SHRINK;         // 3.8mm screw shaft
M4_NUT_WIDTH = 7.0;                                  // Across flats
M4_NUT_HEIGHT = 3.2;
M4_NUT_TRAP_WIDTH = M4_NUT_WIDTH + PRINT_TOLERANCE;  // With tolerance

// Alignment pin dimensions
ALIGN_PIN_DIA = 2.0;
ALIGN_PIN_TOLERANCE = 0.15;
ALIGN_PIN_LENGTH = 8.0;

$fn = 64;

// --- Modules ---

module m4_screw(length=10) {
    // Printable M4 screw with head
    union() {
        // Head (hex socket cap screw profile)
        cylinder(h=M4_HEAD_HEIGHT, d=M4_HEAD_DIAMETER);
        // Shaft
        translate([0, 0, -length])
            cylinder(h=length, d=M4_SHAFT_DIA);
    }
}

module m4_hole(depth=10, countersink=false) {
    // Through-hole for M4 screw with tolerance
    union() {
        cylinder(h=depth + 0.1, d=M4_HOLE_DIA);
        if (countersink) {
            translate([0, 0, depth - M4_HEAD_HEIGHT])
                cylinder(h=M4_HEAD_HEIGHT + 0.1, d=M4_HEAD_DIAMETER + PRINT_TOLERANCE);
        }
    }
}

module m4_nut_trap(depth=3.2) {
    // Hexagonal nut trap (for embedding M4 nut)
    cylinder(h=depth + 0.1, d=M4_NUT_TRAP_WIDTH / cos(30), $fn=6);
}

module m4_threaded_insert(depth=6) {
    // Hole for heat-set threaded insert (M4 x 5.3mm OD)
    INSERT_DIA = 5.4;  // Slightly oversized for melting in
    cylinder(h=depth + 0.5, d=INSERT_DIA);
}

module m4_standoff(height=10, outer_dia=8) {
    // Standoff with M4 through-hole
    difference() {
        cylinder(h=height, d=outer_dia);
        translate([0, 0, -0.05])
            cylinder(h=height + 0.1, d=M4_HOLE_DIA);
    }
}

module alignment_pin() {
    // Press-fit alignment pin
    cylinder(h=ALIGN_PIN_LENGTH, d=ALIGN_PIN_DIA);
}

module alignment_socket(depth=5) {
    // Socket for alignment pin (with tolerance)
    cylinder(h=depth + 0.1, d=ALIGN_PIN_DIA + ALIGN_PIN_TOLERANCE * 2);
}

module m4_bolt_pattern(spacing=20, count=4) {
    // Create a bolt pattern (square arrangement)
    half = spacing / 2;
    positions = [
        [-half, -half],
        [ half, -half],
        [ half,  half],
        [-half,  half]
    ];
    for (i = [0:min(count, 4)-1]) {
        translate([positions[i][0], positions[i][1], 0])
            children();
    }
}

// --- Demo ---
// Uncomment to preview:
// m4_screw(length=16);
// translate([15, 0, 0]) m4_hole(depth=10, countersink=true);
// translate([30, 0, 0]) m4_nut_trap();
// translate([45, 0, 0]) m4_standoff(height=15);
// translate([60, 0, 0]) alignment_pin();
