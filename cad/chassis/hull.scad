// M1A1 Abrams — Hull Chassis (1:26 scale, Gemini-verified proportions)
// Split into front and rear halves for Bambu A1 Mini build volume
// Integrated: hull camera mount, slip-ring void, electronics bay mounting
//
// Key shape notes (Tank Encyclopedia + Gemini):
// - Hull is VERY flat and wide (139mm x 55mm cross-section)
// - Front has a BEAK: lower plate slopes down, upper glacis is near-vertical (82.5 deg)
// - Upper hull sides slope inward above the deck line
// - Full-length side skirts covering track system

use <../libs/common.scad>
use <../libs/m4_hardware.scad>
use <../libs/m3_hardware.scad>
use <../libs/electronics.scad>

// --- Hull Parameters (1:26 scale from real M1A1) ---
hull_length = 150;          // Per half (total 300mm)
hull_width = 139;           // Was 90 — real M1A1 is very wide between tracks
hull_height = 55;           // Was 80 — real M1A1 is very flat
wall = 1.6;                 // Structural walls (min 1.6mm for strength)

// Glacis plate — M1A1 has near-vertical upper plate with a beak
glacis_angle = 82.5;        // Degrees from horizontal (was 30) — almost vertical

// Turret ring (real 2159mm OD / 26.4 scale)
turret_ring_od = 82;        // Was 100
turret_ring_id = 74;        // Was 92
turret_ring_height = 8;

// Battery compartment
battery_length = 70;
battery_width = 40;
battery_height = 30;

// Motor mount dimensions
motor_mount_width = 30;
motor_mount_depth = 40;
motor_mount_height = 25;

// Slip-ring void
slip_ring_dia = 22;             // For wire pass-through to turret

// Hull camera (ESP32-CAM: 40x27x12mm)
hull_cam_width = 30;            // Window width
hull_cam_height = 20;           // Window height (reduced — hull is flatter now)

// Electronics bay mounting (4x M3 in rear hull floor)
ebay_mount_inset = 6;
ebay_mount_x = 138;             // Electronics bay length
ebay_mount_y = 133;             // Was 86 — scaled to new hull_width (hull_width - 2*wall ~= 136)

// Part selector — set via CLI: -D 'part="front"'
part = "assembly";  // "front" | "rear" | "assembly"

// --- M1A1 Hull Shape Parameters ---
upper_taper = 12;          // Was 8 — more inward slope on upper armor
deck_height = hull_height * 0.55;  // Where the upper hull starts tapering (was 0.6)
side_skirt_drop = 15;      // Was 10 — longer side skirts covering tracks
rear_slope = 15;           // Rear deck slope angle

// Beak geometry — the distinctive M1A1 front
beak_drop = 22;            // How far the beak drops below the hull bottom (was 18, more pronounced)
beak_length = 24;          // Forward extension; total front half ~179mm fits 180mm build vol
beak_tip_height = 3;       // Thickness at the beak tip (was 4, sharper)

// Engine deck louver parameters
louver_count = 10;         // More numerous, thinner slits for realism
louver_width = 1.5;        // Thinner louver cuts (was 3)
louver_depth = wall + 0.1; // Cut through deck surface
louver_spacing = 6;        // Tighter spacing (was 10)
louver_length = 40;        // Length of each louver slit

// Rear engine deck slope
rear_deck_slope_deg = 6;   // 6-degree downward slope at rear

// Side skirt flare
skirt_flare = 1.5;         // Outward flare at bottom of skirts (mm)

// Chamfer sizes
chamfer_top = 1.0;         // Top edges where deck meets sides
chamfer_bottom = 0.5;      // Bottom edges of hull
chamfer_skirt = 0.5;       // Side skirt bottom edges

// Greebling parameters
panel_line_depth = 0.2;    // Depth of panel line grooves
panel_line_width = 0.3;    // Width of panel line grooves
driver_hatch_w = 20;       // Driver's hatch width
driver_hatch_l = 15;       // Driver's hatch length
driver_hatch_depth = 0.3;  // Hatch recess depth
tow_hook_dia = 2;          // Tow hook cylinder diameter
tow_hook_length = 3;       // Tow hook protrusion

// Shadow gaps
split_groove_depth = 0.2;  // Visual groove at hull split line
split_groove_width = 0.4;  // Width of split groove
skirt_gap = 0.15;          // Visual separation between skirt and hull

// === AESTHETIC REFINEMENT MODULES ===

// --- Chamfer Edge ---
// 45-degree triangular prism for subtractive edge chamfering
module chamfer_edge(length, size=0.8) {
    rotate([0, 0, 45])
        cube([size*sqrt(2), size*sqrt(2), length], center=true);
}

// --- Hull Chamfers ---
// Subtract chamfers from major hull edges
module hull_chamfers(length) {
    // Top edges: where deck meets sides (left and right)
    // Left top edge
    translate([length/2, 0, hull_height])
        rotate([0, 0, 0])
        chamfer_edge(length + 0.2, chamfer_top);
    // Right top edge
    translate([length/2, hull_width, hull_height])
        chamfer_edge(length + 0.2, chamfer_top);

    // Bottom edges (left and right)
    translate([length/2, 0, 0])
        chamfer_edge(length + 0.2, chamfer_bottom);
    translate([length/2, hull_width, 0])
        chamfer_edge(length + 0.2, chamfer_bottom);

    // Front bottom edge
    translate([0, hull_width/2, 0])
        rotate([0, 90, 0])
        chamfer_edge(hull_width + 0.2, chamfer_bottom);
    // Rear bottom edge
    translate([length, hull_width/2, 0])
        rotate([0, 90, 0])
        chamfer_edge(hull_width + 0.2, chamfer_bottom);
}

// --- Side Skirt Chamfers ---
module skirt_chamfers(length) {
    // Bottom edge chamfers on both side skirts
    for (y_pos = [-2, hull_width]) {
        // Bottom front edge of skirt
        translate([length/2, y_pos + 1, -side_skirt_drop])
            chamfer_edge(length + 0.2, chamfer_skirt);
    }
}

// --- Panel Lines ---
// Horizontal grooves on hull sides for surface detail
module panel_lines(length) {
    line_positions = [deck_height * 0.3, deck_height * 0.6, deck_height * 0.85];
    for (z = line_positions) {
        // Left side
        translate([-0.1, -0.1, z - panel_line_width/2])
            cube([length + 0.2, panel_line_depth + 0.1, panel_line_width]);
        // Right side
        translate([-0.1, hull_width - panel_line_depth, z - panel_line_width/2])
            cube([length + 0.2, panel_line_depth + 0.1, panel_line_width]);
    }
}

// --- Driver's Hatch ---
// Recessed rectangle on front hull top deck
module driver_hatch() {
    // Offset from center toward left (driver sits left of turret on M1A1)
    translate([hull_length * 0.4, hull_width/2 - driver_hatch_w - 5,
               hull_height - driver_hatch_depth])
        cube([driver_hatch_l, driver_hatch_w, driver_hatch_depth + 0.1]);
}

// --- Tow Hooks ---
// Small cylindrical hooks at front corners
module tow_hooks() {
    for (y_off = [8, hull_width - 8]) {
        translate([-tow_hook_length, y_off, deck_height * 0.3])
            rotate([0, 90, 0])
            cylinder(h=tow_hook_length, d=tow_hook_dia, $fn=16);
    }
}

// --- Rear Deck Slope ---
// Angled cut on rear top surface to simulate engine deck slope
module rear_deck_slope(length) {
    // Wedge subtracted from the top-rear of the hull
    slope_start = length * 0.6;  // Start sloping in the rear 40%
    slope_length = length - slope_start;
    slope_drop = slope_length * tan(rear_deck_slope_deg);
    translate([slope_start, -0.1, hull_height - slope_drop])
        rotate([0, 0, 0])
        polyhedron(
            points = [
                [0, 0, slope_drop],                       // 0: start-left-top
                [slope_length, 0, 0],                     // 1: end-left-bottom
                [slope_length, 0, slope_drop],            // 2: end-left-top
                [0, hull_width + 0.2, slope_drop],        // 3: start-right-top
                [slope_length, hull_width + 0.2, 0],      // 4: end-right-bottom
                [slope_length, hull_width + 0.2, slope_drop], // 5: end-right-top
            ],
            faces = [
                [0,1,2],     // left triangle
                [3,5,4],     // right triangle
                [0,3,4,1],   // slope face
                [0,2,5,3],   // top
                [1,4,5,2],   // rear
            ]
        );
}

// --- Split Line Groove ---
// Visual groove at the hull split line for shadow gap effect
module split_line_groove() {
    // Vertical groove on both sides at the split face (X=0 or X=hull_length)
    // Left side
    translate([-split_groove_width/2, -0.1, 0])
        cube([split_groove_width, split_groove_depth + 0.1, hull_height]);
    // Right side
    translate([-split_groove_width/2, hull_width - split_groove_depth, 0])
        cube([split_groove_width, split_groove_depth + 0.1, hull_height]);
    // Top
    translate([-split_groove_width/2, upper_taper, hull_height - split_groove_depth])
        cube([split_groove_width, hull_width - 2*upper_taper, split_groove_depth + 0.1]);
    // Bottom
    translate([-split_groove_width/2, -0.1, -0.1])
        cube([split_groove_width, hull_width + 0.2, split_groove_depth + 0.1]);
}

// --- Skirt Gap ---
// Thin groove between skirt inner face and hull body for visual separation
module skirt_separation(length) {
    for (y_pos = [-2, hull_width]) {
        inner_y = (y_pos < 0) ? y_pos + 2 - skirt_gap : y_pos;
        translate([-0.1, inner_y, -side_skirt_drop])
            cube([length + 0.2, skirt_gap, deck_height + side_skirt_drop - 0.5]);
    }
}

// === END AESTHETIC REFINEMENT MODULES ===

// --- Hull Shape Module ---
// Cross-section: flat bottom, vertical lower sides, tapered upper sides, flat deck
module hull_shape(length) {
    difference() {
        // Outer hull with sloped upper armor
        polyhedron(
            points = [
                // Bottom face (Z=0)
                [0, 0, 0],                                    // 0: front-left-bottom
                [length, 0, 0],                               // 1: rear-left-bottom
                [length, hull_width, 0],                      // 2: rear-right-bottom
                [0, hull_width, 0],                           // 3: front-right-bottom
                // Deck line (Z=deck_height)
                [0, 0, deck_height],                          // 4: front-left-deck
                [length, 0, deck_height],                     // 5: rear-left-deck
                [length, hull_width, deck_height],             // 6: rear-right-deck
                [0, hull_width, deck_height],                  // 7: front-right-deck
                // Top face (Z=hull_height, tapered inward)
                [0, upper_taper, hull_height],                 // 8: front-left-top
                [length, upper_taper, hull_height],            // 9: rear-left-top
                [length, hull_width-upper_taper, hull_height], // 10: rear-right-top
                [0, hull_width-upper_taper, hull_height],      // 11: front-right-top
            ],
            faces = [
                [3,2,1,0],     // bottom
                [8,9,10,11],   // top
                [0,1,5,4],     // left lower
                [4,5,9,8],     // left upper (sloped)
                [2,3,7,6],     // right lower
                [6,7,11,10],   // right upper (sloped)
                [0,4,8,11,7,3],// front
                [1,2,6,10,9,5],// rear
            ]
        );

        // Hollow interior (offset inward by wall thickness)
        translate([wall, wall, wall])
            cube([length - 2*wall, hull_width - 2*wall, hull_height]);
    }

    // Side skirts — full-length plates with slight outward flare at bottom
    for (y_pos = [-2, hull_width]) {
        flare_dir = (y_pos < 0) ? -1 : 1;  // Flare outward from hull
        polyhedron(
            points = [
                // Top edge (flush with hull)
                [0, y_pos, deck_height],
                [length, y_pos, deck_height],
                [length, y_pos + 2, deck_height],
                [0, y_pos + 2, deck_height],
                // Bottom edge (flared outward)
                [0, y_pos + flare_dir * skirt_flare, -side_skirt_drop],
                [length, y_pos + flare_dir * skirt_flare, -side_skirt_drop],
                [length, y_pos + 2 + flare_dir * skirt_flare, -side_skirt_drop],
                [0, y_pos + 2 + flare_dir * skirt_flare, -side_skirt_drop],
            ],
            faces = [
                [3,2,1,0],   // top
                [4,5,6,7],   // bottom
                [0,1,5,4],   // outer
                [2,3,7,6],   // inner
                [0,4,7,3],   // front
                [1,2,6,5],   // rear
            ]
        );
    }
}

// --- Beak + Glacis ---
// M1A1 front: lower beak slopes downward, upper glacis is near-vertical
module glacis_plate() {
    // The beak: triangular wedge sloping downward from hull front
    // Forms the distinctive M1A1 "beak" shape
    hull() {
        // Top edge of beak at hull front face, at about deck_height
        translate([0, wall, 0])
            cube([wall, hull_width - 2*wall, deck_height]);
        // Beak tip — extends forward and drops below hull bottom
        translate([-beak_length, hull_width * 0.15, -beak_drop])
            cube([wall, hull_width * 0.7, beak_tip_height]);
    }

    // Upper glacis — near-vertical plate above the beak
    // At 82.5 degrees from horizontal, the horizontal setback is tiny:
    // hull_height_above_deck * cos(82.5) ~= (hull_height - deck_height) * 0.13
    glacis_setback = (hull_height - deck_height) / tan(glacis_angle);
    hull() {
        // Bottom edge at deck_height on the hull face
        translate([0, wall, deck_height])
            cube([wall, hull_width - 2*wall, 0.1]);
        // Top edge — slightly forward of hull face due to steep angle
        translate([-glacis_setback, upper_taper, hull_height - 0.1])
            cube([wall, hull_width - 2*upper_taper, 0.1]);
    }
}

module turret_ring() {
    difference() {
        cylinder(h=turret_ring_height, d=turret_ring_od);
        translate([0, 0, -0.05])
            cylinder(h=turret_ring_height + 0.1, d=turret_ring_id);
    }
}

module battery_compartment() {
    difference() {
        cube([battery_length + 2*wall, battery_width + 2*wall, battery_height + wall]);
        translate([wall, wall, wall])
            cube([battery_length, battery_width, battery_height + 0.1]);
    }
}

module motor_mount() {
    difference() {
        cube([motor_mount_depth, motor_mount_width, motor_mount_height]);
        // Motor shaft hole
        translate([motor_mount_depth/2, motor_mount_width/2, -0.1])
            cylinder(h=motor_mount_height + 0.2, d=6);
        // Mounting holes
        for (dx = [-10, 10])
            for (dy = [-8, 8])
                translate([motor_mount_depth/2 + dx, motor_mount_width/2 + dy, -0.1])
                    m4_hole(depth=motor_mount_height + 0.2);
    }
}

module hull_cam_mount() {
    // ESP32-CAM cradle at front of hull (driver camera, fixed position)
    // Centered in hull width, positioned in upper half of hull face
    // ESP32-CAM is 40x27x12mm — hull_width=139 gives plenty of centering room
    translate([wall + 2, hull_width/2 - 13.5, hull_height * 0.4 + 2])
        esp32cam_mount(standoff_h=3);
}

// --- Front Hull Half ---
module hull_front() {
    difference() {
        union() {
            hull_shape(hull_length);
            glacis_plate();
            hull_cam_mount();
            tow_hooks();  // Tow hooks at front corners
        }

        // ESP32-CAM front window (lens aperture)
        translate([-beak_length - 0.1, hull_width/2 - hull_cam_width/2, hull_height * 0.4])
            cube([beak_length + wall + 5, hull_cam_width, hull_cam_height]);

        // Aesthetic: chamfers on major edges
        hull_chamfers(hull_length);
        skirt_chamfers(hull_length);

        // Aesthetic: panel lines on hull sides
        panel_lines(hull_length);

        // Aesthetic: driver's hatch on top deck
        driver_hatch();

        // Aesthetic: skirt visual separation
        skirt_separation(hull_length);

        // Aesthetic: split line groove at rear face (mating face)
        translate([hull_length, 0, 0])
            split_line_groove();
    }

    // Motor mounts (front pair — one per side)
    for (side = [0, 1])
        translate([20, side * (hull_width - motor_mount_width), 0])
            motor_mount();

    // Split joint — alignment keys (at hull_length face, mating with rear half)
    translate([hull_length, hull_width/4, hull_height/3])
        split_key();
    translate([hull_length, hull_width*3/4, hull_height/3])
        split_key();

    // Split joint — M4 bolt holes
    translate([hull_length - 5, hull_width/4, hull_height*2/3])
        rotate([0, 90, 0]) m4_hole(depth=10);
    translate([hull_length - 5, hull_width*3/4, hull_height*2/3])
        rotate([0, 90, 0]) m4_hole(depth=10);
}

// --- Electronics Bay Floor Mounts ---
module ebay_floor_mounts() {
    // M3 threaded holes in hull floor for electronics bay mounting
    ebay_ox = (hull_length - ebay_mount_x) / 2;
    ebay_oy = (hull_width - ebay_mount_y) / 2;
    positions = [
        [ebay_ox + ebay_mount_inset,                  ebay_oy + ebay_mount_inset],
        [ebay_ox + ebay_mount_x - ebay_mount_inset,   ebay_oy + ebay_mount_inset],
        [ebay_ox + ebay_mount_inset,                  ebay_oy + ebay_mount_y - ebay_mount_inset],
        [ebay_ox + ebay_mount_x - ebay_mount_inset,   ebay_oy + ebay_mount_y - ebay_mount_inset]
    ];
    for (p = positions)
        translate([p[0], p[1], -0.05])
            m3_hole(depth=wall + 0.1);
}

// --- Engine Deck Louvers ---
// Rectangular cutouts in the rear deck top surface simulating engine ventilation
module engine_deck_louvers() {
    // M1A1 has louver grilles on the rear engine deck, arranged in two groups
    // Position: rear portion of the hull half, on the top surface
    louver_start_x = hull_length * 0.65;  // Start in rear 35% of hull half
    for (side = [0, 1]) {
        side_offset = (side == 0) ?
            hull_width/2 - louver_length/2 - 10 :   // Left group
            hull_width/2 + 10;                        // Right group
        for (i = [0 : louver_count - 1]) {
            translate([
                louver_start_x + i * louver_spacing,
                side_offset,
                hull_height - louver_depth
            ])
                cube([louver_width, louver_length, louver_depth + 0.1]);
        }
    }
}

// --- Rear Hull Half ---
module hull_rear() {
    difference() {
        hull_shape(hull_length);

        // Split joint — alignment sockets (mating with front half keys)
        translate([0, hull_width/4, hull_height/3])
            split_socket();
        translate([0, hull_width*3/4, hull_height/3])
            split_socket();

        // Split joint — M4 bolt holes
        translate([-5, hull_width/4, hull_height*2/3])
            rotate([0, 90, 0]) m4_hole(depth=10);
        translate([-5, hull_width*3/4, hull_height*2/3])
            rotate([0, 90, 0]) m4_hole(depth=10);

        // Slip-ring void at turret ring center
        translate([hull_length/2, hull_width/2, hull_height - 0.05])
            cylinder(h=turret_ring_height + 0.2, d=slip_ring_dia);

        // Electronics bay mounting holes in floor
        ebay_floor_mounts();

        // Engine deck louvers (ventilation detail — thinner, more numerous)
        engine_deck_louvers();

        // Aesthetic: rear engine deck slope (5-8 deg downward)
        rear_deck_slope(hull_length);

        // Aesthetic: chamfers on major edges
        hull_chamfers(hull_length);
        skirt_chamfers(hull_length);

        // Aesthetic: panel lines on hull sides
        panel_lines(hull_length);

        // Aesthetic: skirt visual separation
        skirt_separation(hull_length);

        // Aesthetic: split line groove at front face (mating face)
        split_line_groove();
    }

    // Turret ring (centered on rear half)
    translate([hull_length/2, hull_width/2, hull_height])
        turret_ring();
}

// --- Full Assembly (both halves) ---
module hull_assembly() {
    hull_front();
    translate([hull_length, 0, 0])
        hull_rear();
}

// Render selected part
if (part == "front") hull_front();
else if (part == "rear") hull_rear();
else if (part == "assembly") hull_assembly();
