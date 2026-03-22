// =============================================================================
// Plarail-Compatible Track & FPV Tunnel System
// ROBOT4KID Project
// =============================================================================
// All dimensions in mm. Printable without supports on Bambu A1 Mini (180x180x180).
// Rail gauge: 27mm center-to-center (Plarail standard per hardware_specs.yaml).
// =============================================================================

$fn = 48;

// --- Part Selector -----------------------------------------------------------
// "straight" | "curve" | "portal" | "tunnel" | "layout"
part = "layout";

// =============================================================================
// PARAMETERS
// =============================================================================

// Track bed
bed_width       = 50;
bed_thickness   = 3;

// Rails
rail_gauge      = 27;   // center-to-center (Plarail standard per hardware_specs.yaml)
rail_width      = 3;
rail_height     = 4;

// Sleeper grooves
sleeper_spacing = 15;
sleeper_depth   = 0.3;
sleeper_width   = 1.0;  // along track length

// Joints
joint_length    = 8;
joint_width     = 10;
joint_height    = 3;
joint_tol       = 0.2;  // tolerance per side

// Straight track
straight_length = 215;

// Curve track
curve_radius    = 160;  // center-line radius
curve_angle     = 45;   // 8 pieces = full circle

// Tunnel portal
portal_arch_w   = 55;
portal_arch_h   = 65;
portal_total_w  = 70;
portal_total_h  = 100;
portal_depth    = 12;   // thickness of portal face
portal_wall     = 4;

// Tunnel section
tunnel_length   = 100;
tunnel_wall     = 3;

// Rail channel in tunnel/portal base
rail_chan_width  = 4;    // slightly wider than rail for clearance
rail_chan_depth  = 5;    // deeper than rail height for clearance

// Brick pattern
brick_w         = 10;
brick_h         = 5;
brick_depth     = 1.0;
mortar_w        = 0.8;

// =============================================================================
// UTILITY MODULES
// =============================================================================

// Single rail profile: a rectangular bar
module rail(length) {
    translate([0, 0, bed_thickness])
        cube([length, rail_width, rail_height]);
}

// Two parallel rails
module rails(length) {
    // Left rail
    translate([0, (bed_width - rail_gauge) / 2 - rail_width / 2, 0])
        rail(length);
    // Right rail
    translate([0, (bed_width + rail_gauge) / 2 - rail_width / 2, 0])
        rail(length);
}

// Sleeper grooves cut into the bed top surface
module sleeper_grooves(length) {
    num_sleepers = floor(length / sleeper_spacing);
    for (i = [1 : num_sleepers - 1]) {
        translate([i * sleeper_spacing - sleeper_width / 2, 0, bed_thickness - sleeper_depth])
            cube([sleeper_width, bed_width, sleeper_depth + 0.01]);
    }
}

// Male joint tab (extends from track end)
module male_joint() {
    translate([0, (bed_width - joint_width) / 2, 0])
        cube([joint_length, joint_width, joint_height]);
}

// Female joint socket (cut into track end)
module female_socket() {
    sw = joint_width + 2 * joint_tol;
    sl = joint_length + joint_tol;
    sh = joint_height + joint_tol;
    translate([-sl, (bed_width - sw) / 2, -0.01])
        cube([sl + 0.01, sw, sh + 0.01]);
}

// Gothic/pointed arch profile (2D) - support-free with max 45deg
// Uses two circular arcs meeting at a point
module arch_profile_2d(w, h) {
    // Pointed arch: two arcs with centers offset inward
    r = h * 0.7;  // radius of each arc
    cx = w * 0.15; // how far inward the centers are from the edges
    intersection() {
        // Left arc
        translate([w / 2 - cx, 0])
            circle(r = r);
        // Right arc
        translate([-w / 2 + cx, 0])
            circle(r = r);
        // Clip to above baseline and within width
        translate([-w / 2, 0])
            square([w, h]);
    }
    // Rectangular base portion to ensure full width at bottom
    translate([-w / 2, 0])
        square([w, h * 0.55]);
}

// Rail channels through tunnel/portal base
module rail_channels(length) {
    // Left channel
    translate([-0.01, (bed_width - rail_gauge) / 2 - rail_chan_width / 2, 0])
        cube([length + 0.02, rail_chan_width, rail_chan_depth]);
    // Right channel
    translate([-0.01, (bed_width + rail_gauge) / 2 - rail_chan_width / 2, 0])
        cube([length + 0.02, rail_chan_width, rail_chan_depth]);
}

// =============================================================================
// 1. STRAIGHT TRACK
// =============================================================================

module straight_track(length = straight_length) {
    body_len = length - joint_length; // main body without male tab

    difference() {
        union() {
            // Bed
            cube([body_len, bed_width, bed_thickness]);
            // Rails
            rails(body_len);
            // Male joint at +X end
            translate([body_len, 0, 0])
                male_joint();
        }
        // Female socket at -X end (0)
        female_socket();
        // Sleeper grooves
        sleeper_grooves(body_len);
    }
}

// =============================================================================
// 2. CURVE TRACK
// =============================================================================

module curve_track(radius = curve_radius, angle = curve_angle) {
    inner_r = radius - bed_width / 2;
    outer_r = radius + bed_width / 2;
    rail_left_r_inner  = radius - rail_gauge / 2 - rail_width / 2;
    rail_left_r_outer  = radius - rail_gauge / 2 + rail_width / 2;
    rail_right_r_inner = radius + rail_gauge / 2 - rail_width / 2;
    rail_right_r_outer = radius + rail_gauge / 2 + rail_width / 2;

    // Arc length for joint sizing
    arc_len = 2 * PI * radius * angle / 360;
    joint_angle = (joint_length / (2 * PI * radius)) * 360;

    difference() {
        union() {
            // Bed - curved arc
            linear_extrude(height = bed_thickness)
                difference() {
                    // Outer arc
                    intersection() {
                        circle(r = outer_r);
                        _wedge(angle);
                    }
                    circle(r = inner_r);
                }

            // Left rail (inner)
            translate([0, 0, bed_thickness])
                linear_extrude(height = rail_height)
                    difference() {
                        intersection() {
                            circle(r = rail_left_r_outer);
                            _wedge(angle);
                        }
                        circle(r = rail_left_r_inner);
                    }

            // Right rail (outer)
            translate([0, 0, bed_thickness])
                linear_extrude(height = rail_height)
                    difference() {
                        intersection() {
                            circle(r = rail_right_r_outer);
                            _wedge(angle);
                        }
                        circle(r = rail_right_r_inner);
                    }

            // Male joint at angle end
            rotate([0, 0, angle])
                translate([inner_r, 0, 0])
                    rotate([0, 0, 0])
                        _curve_male_joint(inner_r, outer_r);

        }
        // Female socket at 0-degree end
        _curve_female_socket(inner_r, outer_r);

        // Sleeper grooves (radial lines)
        num_sleepers = floor(arc_len / sleeper_spacing);
        for (i = [1 : num_sleepers - 1]) {
            a = i * angle / num_sleepers;
            rotate([0, 0, a])
                translate([inner_r - 0.5, -sleeper_width / 2, bed_thickness - sleeper_depth])
                    cube([outer_r - inner_r + 1, sleeper_width, sleeper_depth + 0.01]);
        }
    }
}

// Wedge shape for intersection (pie slice from 0 to angle degrees)
module _wedge(angle) {
    r = 300; // large enough to cover
    if (angle <= 180) {
        intersection() {
            // Half-plane from 0 degrees
            translate([0, 0]) square([r, r]);
            // Half-plane rotated to angle
            rotate([0, 0, angle]) translate([-r, 0]) square([r * 2, r]);
        }
    } else {
        union() {
            translate([0, 0]) square([r, r]);
            rotate([0, 0, angle]) translate([0, 0]) square([r, r]);
        }
    }
}

// Male joint for curve (at the end of the arc)
module _curve_male_joint(inner_r, outer_r) {
    mid_r = (inner_r + outer_r) / 2;
    translate([mid_r - inner_r - joint_width / 2, 0, 0])
        cube([joint_width, joint_length, joint_height]);
}

// Female socket for curve (at the start of the arc, 0 degrees)
module _curve_female_socket(inner_r, outer_r) {
    mid_r = (inner_r + outer_r) / 2;
    sw = joint_width + 2 * joint_tol;
    sl = joint_length + joint_tol;
    sh = joint_height + joint_tol;
    translate([mid_r - sw / 2, -sl, -0.01])
        cube([sw, sl + 0.01, sh + 0.01]);
}

// =============================================================================
// 3. TUNNEL PORTAL
// =============================================================================

module tunnel_portal() {
    difference() {
        union() {
            // Main portal body
            _portal_body();
        }
        // Arch opening through the portal
        translate([portal_depth / 2, 0, 0])
            rotate([0, 90, 0])
                rotate([0, 0, 90])
                    linear_extrude(height = portal_depth + 0.02, center = true)
                        arch_profile_2d(portal_arch_w, portal_arch_h);

        // Rail channels through base
        translate([0, -bed_width / 2, 0])
            rail_channels(portal_depth);

        // Brick pattern on front face
        translate([-0.01, 0, 0])
            _brick_pattern();

        // Brick pattern on rear face
        translate([portal_depth + 0.01, 0, 0])
            mirror([1, 0, 0])
                _brick_pattern();
    }
}

module _portal_body() {
    // Base slab that sits on track (wider than portal for stability)
    base_w = portal_total_w;
    base_h = rail_chan_depth + 2;
    translate([0, -base_w / 2, 0])
        cube([portal_depth, base_w, base_h]);

    // Portal face with arch shape
    // Outer shape: rounded rectangle with pointed top
    translate([0, -portal_total_w / 2, 0])
        cube([portal_depth, portal_total_w, portal_total_h * 0.6]);

    // Upper arch section
    translate([0, 0, 0])
        linear_extrude(height = portal_depth)
            rotate([0, 0, 0])
                translate([0, 0, 0])
                    _portal_face_2d();

    // Actually build as a solid block and subtract the arch
    translate([0, -portal_total_w / 2, 0])
        cube([portal_depth, portal_total_w, portal_total_h]);
}

// 2D portal face shape (for extrusion) - not actually used, using solid block instead
module _portal_face_2d() {
    // Placeholder - the solid block approach is cleaner
}

// Brick pattern relief on one face
module _brick_pattern() {
    rows = floor(portal_total_h / (brick_h + mortar_w));
    cols = floor(portal_total_w / (brick_w + mortar_w));

    for (row = [0 : rows - 1]) {
        z_pos = row * (brick_h + mortar_w);
        x_offset = (row % 2 == 0) ? 0 : (brick_w + mortar_w) / 2;

        for (col = [-cols : cols]) {
            y_pos = col * (brick_w + mortar_w) + x_offset - portal_total_w / 2;

            // Horizontal mortar line
            translate([0, -portal_total_w / 2 - 1, z_pos + brick_h])
                cube([brick_depth, portal_total_w + 2, mortar_w]);
        }
        // Vertical mortar lines for this row
        for (col = [-cols : cols]) {
            y_pos = col * (brick_w + mortar_w) + x_offset;
            translate([0, y_pos - mortar_w / 2, z_pos])
                cube([brick_depth, mortar_w, brick_h]);
        }
    }
}

// =============================================================================
// 4. TUNNEL SECTION
// =============================================================================

module tunnel_section(length = tunnel_length) {
    int_w = portal_arch_w + 2;  // slightly wider for clearance
    int_h = portal_arch_h + 2;
    ext_w = int_w + 2 * tunnel_wall;
    ext_h = int_h + tunnel_wall;

    difference() {
        // Exterior shell - rectangular with arch top for print-friendliness
        union() {
            // Rectangular base
            translate([0, -ext_w / 2, 0])
                cube([length, ext_w, int_h * 0.6 + tunnel_wall]);

            // Arch top
            translate([0, 0, 0])
                linear_extrude(height = length)
                    rotate([0, 0, 0])
                        _tunnel_exterior_2d(ext_w, ext_h);

            // Full rectangular exterior
            translate([0, -ext_w / 2, 0])
                cube([length, ext_w, ext_h]);
        }

        // Interior arch cutout
        translate([-0.01, 0, 0])
            linear_extrude(height = length + 0.02)
                rotate([0, 0, 0])
                    _tunnel_interior_2d(int_w, int_h);

        // Rotate interior arch to go along X axis
        translate([length / 2, 0, 0])
            rotate([0, 90, 0])
                rotate([0, 0, 90])
                    linear_extrude(height = length + 0.02, center = true)
                        arch_profile_2d(int_w, int_h);

        // Rail channels through base
        translate([0, -bed_width / 2, 0])
            rail_channels(length);
    }
}

// 2D profiles for tunnel (fallbacks, main cutout uses arch_profile_2d)
module _tunnel_exterior_2d(w, h) {
    translate([-w / 2, 0])
        square([w, h]);
}

module _tunnel_interior_2d(w, h) {
    translate([-w / 2, 0])
        square([w, h * 0.5]);
}

// =============================================================================
// 5. DEMO LAYOUT
// =============================================================================

module layout() {
    // Two straight tracks end-to-end
    color("SteelBlue")
        straight_track();

    color("SteelBlue")
        translate([straight_length + 5, 0, 0])
            straight_track();

    // Portal at start of first straight
    color("SandyBrown")
        translate([30, bed_width / 2, 0])
            tunnel_portal();

    // Tunnel section behind first portal
    color("Sienna")
        translate([30 + portal_depth + 0.5, bed_width / 2, 0])
            tunnel_section(length = 80);

    // Second portal at end of tunnel
    color("SandyBrown")
        translate([30 + portal_depth + 80 + 0.5 + portal_depth, bed_width / 2, 0])
            mirror([1, 0, 0])
                tunnel_portal();

    // A curve track piece for visual interest
    color("CornflowerBlue")
        translate([straight_length * 2 + 15, bed_width / 2, 0])
            rotate([0, 0, -90])
                curve_track();
}

// =============================================================================
// PART SELECTOR
// =============================================================================

if (part == "straight") {
    straight_track();
} else if (part == "curve") {
    curve_track();
} else if (part == "portal") {
    tunnel_portal();
} else if (part == "tunnel") {
    tunnel_section();
} else if (part == "layout") {
    layout();
}
