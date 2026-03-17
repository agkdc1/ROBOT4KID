// Common dimensions and utilities for NL2Bot
// All dimensions in millimeters

// --- Printer Constraints ---
BUILD_X = 180;
BUILD_Y = 180;
BUILD_Z = 180;
WALL_THICKNESS = 1.2;        // 3 perimeters at 0.4mm
MIN_WALL = 0.8;              // 2 perimeters minimum
LAYER_HEIGHT = 0.2;
NOZZLE_DIA = 0.4;
PRINT_TOLERANCE = 0.2;

// --- Tank Overall Dimensions (1:26 scale from real M1A1) ---
// Target: fits within 2 build volumes length-wise (split chassis)
TANK_LENGTH = 300;            // Total length (split into 2 halves)
TANK_WIDTH = 187;             // Width including tracks (139 hull + 2*24 tracks)
TANK_HEIGHT = 55;             // Hull height (without turret) — M1A1 is very flat
TRACK_WIDTH = 24;             // Track width per side (real 635mm / 26.4)
HULL_WIDTH = 139;             // Between tracks — real M1A1 is wide

// Turret
TURRET_DIAMETER = 82;         // Turret ring diameter (real 2159mm / 26.4)
TURRET_HEIGHT = 30;           // Turret body height — M1A1 is very low profile
BARREL_DIAMETER = 12;         // Gun barrel outer diameter
BARREL_LENGTH = 180;          // Gun barrel length (real 5280mm / 26.4 ≈ 200, fit to build vol)

// Console cradle
CONSOLE_WIDTH = 270;          // 10-inch tablet width + margins
CONSOLE_DEPTH = 180;          // Tablet depth + controls
CONSOLE_HEIGHT = 60;          // Cradle height

// --- Common Modules ---

module rounded_cube(size, r=2) {
    // Cube with rounded vertical edges
    hull() {
        for (x = [r, size[0]-r])
            for (y = [r, size[1]-r])
                translate([x, y, 0])
                    cylinder(h=size[2], r=r);
    }
}

module shell(size, wall=WALL_THICKNESS) {
    // Hollow box with given wall thickness
    difference() {
        rounded_cube(size);
        translate([wall, wall, wall])
            rounded_cube([
                size[0] - 2*wall,
                size[1] - 2*wall,
                size[2]  // Open top
            ]);
    }
}

module split_key(size=4, height=3) {
    // Alignment key for split parts — male side
    translate([0, 0, 0])
        cylinder(h=height, d1=size, d2=size-0.5);
}

module split_socket(size=4, height=3) {
    // Alignment key socket — female side (with tolerance)
    translate([0, 0, -0.05])
        cylinder(h=height + 0.1, d1=size + PRINT_TOLERANCE*2, d2=size - 0.5 + PRINT_TOLERANCE*2);
}

$fn = 64;
