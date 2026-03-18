// hardware_v2.scad — Unified hardware library (M2/M3/M4)
// ISO 4762 socket head cap screws, ISO 4032 hex nuts,
// heat-set inserts, clearance holes, nut traps, standoffs.
// All dimensions in mm. No external dependencies.
//
// Usage:
//   use <hardware_v2.scad>
//   m3_screw(length=12);
//   m3_nut();
//   m3_insert(depth=4);

$fn = 48;

// ============================================================
// Part selector for demo
// ============================================================
part = "none"; // set to "demo" to show all hardware

// ============================================================
// ISO 4762 — Socket Head Cap Screws
// ============================================================
// Head sits on Z=0, shaft extends downward (-Z).
// Hex socket is a recess in the top of the head.

module _shcs(d_shaft, d_head, h_head, af_socket, length) {
    color("Silver") {
        // Head
        difference() {
            cylinder(d=d_head, h=h_head);
            // Hex socket recess (60% of head height)
            translate([0, 0, h_head * 0.4])
                linear_extrude(h_head * 0.65)
                    circle(d=af_socket / cos(30), $fn=6);
        }
        // Shaft (extends downward)
        translate([0, 0, -length])
            cylinder(d=d_shaft, h=length);
    }
}

module m2_screw(length=6) {
    // ISO 4762 M2: head d=3.8, h=2.0, socket AF=1.5
    _shcs(d_shaft=2.0, d_head=3.8, h_head=2.0, af_socket=1.5, length=length);
}

module m3_screw(length=8) {
    // ISO 4762 M3: head d=5.5, h=3.0, socket AF=2.5
    _shcs(d_shaft=3.0, d_head=5.5, h_head=3.0, af_socket=2.5, length=length);
}

module m4_screw(length=10) {
    // ISO 4762 M4: head d=7.0, h=4.0, socket AF=3.0
    _shcs(d_shaft=4.0, d_head=7.0, h_head=4.0, af_socket=3.0, length=length);
}

// ============================================================
// ISO 4032 — Hex Nuts
// ============================================================
// Nut sits on Z=0, centered at origin.

module _hex_nut(d_bore, af, h) {
    color("DimGray") {
        difference() {
            // Hex body (AF = across flats)
            linear_extrude(h)
                circle(d=af / cos(30), $fn=6);
            // Through bore
            translate([0, 0, -0.01])
                cylinder(d=d_bore, h=h+0.02);
        }
    }
}

module m2_nut() {
    // ISO 4032 M2: AF=4.0, h=1.6
    _hex_nut(d_bore=2.0, af=4.0, h=1.6);
}

module m3_nut() {
    // ISO 4032 M3: AF=5.5, h=2.4
    _hex_nut(d_bore=3.0, af=5.5, h=2.4);
}

module m4_nut() {
    // ISO 4032 M4: AF=7.0, h=3.2
    _hex_nut(d_bore=4.0, af=7.0, h=3.2);
}

// ============================================================
// Heat-Set Inserts (brass knurled)
// ============================================================
// Insert sits on Z=0, centered at origin.
// Knurl approximated with vertical grooves around the OD.

module _heat_set_insert(d_bore, d_outer, depth, n_knurls=12) {
    color("Gold") {
        difference() {
            union() {
                // Main body
                cylinder(d=d_outer, h=depth);
                // Slight taper at bottom for insertion
                cylinder(d1=d_outer + 0.3, d2=d_outer, h=depth * 0.25);
            }
            // Through bore
            translate([0, 0, -0.01])
                cylinder(d=d_bore, h=depth + 0.02);
            // Knurl grooves
            for (i = [0:n_knurls-1]) {
                rotate([0, 0, i * 360/n_knurls])
                    translate([d_outer/2, 0, -0.01])
                        cylinder(d=0.3, h=depth + 0.02);
            }
        }
    }
}

module m2_insert(depth=3) {
    // M2 heat-set: OD=3.2mm
    _heat_set_insert(d_bore=2.0, d_outer=3.2, depth=depth);
}

module m3_insert(depth=4) {
    // M3 heat-set: OD=4.0mm
    _heat_set_insert(d_bore=3.0, d_outer=4.0, depth=depth);
}

// ============================================================
// Clearance Holes (for difference operations)
// ============================================================
// Centered at origin, extends from Z=0 downward (-Z).
// Add 0.01 margins for clean boolean ops.

module _clearance_hole(d, depth) {
    translate([0, 0, -depth])
        cylinder(d=d, h=depth + 0.02);
}

module m2_clearance_hole(depth=10) {
    _clearance_hole(d=2.4, depth=depth);
}

module m3_clearance_hole(depth=10) {
    _clearance_hole(d=3.4, depth=depth);
}

module m4_clearance_hole(depth=10) {
    _clearance_hole(d=4.5, depth=depth);
}

// ============================================================
// Nut Traps (hex pocket for captive nut)
// ============================================================
// Hex pocket at Z=0, extends downward (-Z).
// 0.2mm clearance added to AF for print tolerance.

module _nut_trap(af, depth) {
    af_clearance = af + 0.2;
    translate([0, 0, -depth])
        linear_extrude(depth + 0.02)
            circle(d=af_clearance / cos(30), $fn=6);
}

module m2_nut_trap(depth=2) {
    _nut_trap(af=4.0, depth=depth);
}

module m3_nut_trap(depth=3) {
    _nut_trap(af=5.5, depth=depth);
}

module m4_nut_trap(depth=4) {
    _nut_trap(af=7.0, depth=depth);
}

// ============================================================
// Standoffs (hex, female-female)
// ============================================================
// Standoff sits on Z=0, centered at origin.
// Threaded bores on both ends (3mm deep).

module _standoff(af, d_bore, height, bore_depth=3) {
    color("Silver") {
        difference() {
            // Hex body
            linear_extrude(height)
                circle(d=af / cos(30), $fn=6);
            // Bottom bore
            translate([0, 0, -0.01])
                cylinder(d=d_bore, h=bore_depth + 0.01);
            // Top bore
            translate([0, 0, height - bore_depth])
                cylinder(d=d_bore, h=bore_depth + 0.01);
        }
    }
}

module m2_standoff(height=5) {
    // M2 standoff: AF=4mm
    _standoff(af=4.0, d_bore=2.0, height=height);
}

module m3_standoff(height=8) {
    // M3 standoff: AF=5.5mm
    _standoff(af=5.5, d_bore=3.0, height=height);
}

// ============================================================
// Demo — show all hardware in a row
// ============================================================

module _demo() {
    spacing = 15;

    // Row 1: Screws
    translate([0, 0, 0]) {
        translate([0*spacing, 0, 10]) m2_screw(length=6);
        translate([1*spacing, 0, 10]) m3_screw(length=8);
        translate([2*spacing, 0, 10]) m4_screw(length=10);
    }

    // Row 2: Nuts
    translate([0, -spacing, 0]) {
        translate([0*spacing, 0, 0]) m2_nut();
        translate([1*spacing, 0, 0]) m3_nut();
        translate([2*spacing, 0, 0]) m4_nut();
    }

    // Row 3: Inserts
    translate([0, -2*spacing, 0]) {
        translate([0*spacing, 0, 0]) m2_insert(depth=3);
        translate([1*spacing, 0, 0]) m3_insert(depth=4);
    }

    // Row 4: Standoffs
    translate([0, -3*spacing, 0]) {
        translate([0*spacing, 0, 0]) m2_standoff(height=5);
        translate([1*spacing, 0, 0]) m3_standoff(height=8);
    }

    // Row 5: Clearance holes (shown as red cylinders for visibility)
    translate([0, -4*spacing, 0]) {
        color("Red", 0.5) {
            translate([0*spacing, 0, 0]) m2_clearance_hole(depth=10);
            translate([1*spacing, 0, 0]) m3_clearance_hole(depth=10);
            translate([2*spacing, 0, 0]) m4_clearance_hole(depth=10);
        }
    }

    // Row 6: Nut traps (shown as red hex pockets for visibility)
    translate([0, -5*spacing, 0]) {
        color("Red", 0.5) {
            translate([0*spacing, 0, 0]) m2_nut_trap(depth=2);
            translate([1*spacing, 0, 0]) m3_nut_trap(depth=3);
            translate([2*spacing, 0, 0]) m4_nut_trap(depth=4);
        }
    }
}

if (part == "demo") _demo();
