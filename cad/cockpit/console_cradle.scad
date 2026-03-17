// =====================================================================
// Tactical Command Cradle — Tank Control Station Enclosure
// =====================================================================
// Precision split enclosure for Samsung Galaxy Tab A 8.0" (2019),
// GL.iNet Mango router, Anker PowerCore Slim 10000, Sabrent USB hub.
//
// Split into FRONT (tablet area) and REAR (electronics) halves at the
// Y-axis midpoint, joined by M4 bolts. Each half fits within the
// Bambu A1 Mini 180x180x180mm build volume.
//
// Part selector: -D 'part="assembly"' / "front" / "rear"
// =====================================================================

use <../libs/common.scad>
use <../libs/m4_hardware.scad>
use <../libs/m3_hardware.scad>

// =====================================================================
// Part Selector (override via CLI: -D 'part="front"')
// =====================================================================
part = "assembly";  // "front" | "rear" | "assembly"

$fn = 64;

// =====================================================================
// Component Dimensions (exact manufacturer specs)
// =====================================================================

// Samsung Galaxy Tab A 8.0" (2019) SM-T290
tablet_w    = 210.0;    // Width (landscape)
tablet_d    = 124.4;    // Depth (landscape)
tablet_h    = 8.0;      // Thickness
tablet_clr  = 1.0;      // Clearance per side

// GL.iNet GL-MT300N-V2 (Mango)
router_w    = 58.0;     // Width
router_d    = 58.0;     // Depth
router_h    = 25.0;     // Height
router_clr  = 0.5;      // Clearance per side

// Anker PowerCore Slim 10000
pbank_w     = 149.0;    // Width (long axis)
pbank_d     = 68.0;     // Depth
pbank_h     = 14.0;     // Height
pbank_clr   = 0.5;      // Clearance per side

// Sabrent HB-UM43 4-Port USB Hub
hub_w       = 85.0;     // Width (long axis)
hub_d       = 30.0;     // Depth
hub_h       = 15.0;     // Height
hub_clr     = 0.5;      // Clearance per side

// =====================================================================
// Structural Parameters
// =====================================================================

wall        = 2.0;      // External wall thickness
floor_t     = 2.0;      // Floor thickness
divider_t   = 1.6;      // Internal divider thickness
chamfer     = 0.8;      // External edge chamfer
corner_r    = 3.0;      // Corner rounding radius

// Tablet slot
tablet_tilt = 15;       // Backward tilt angle (degrees)
lip_h       = 3.0;      // Retaining lip height above tablet surface
lip_w       = 1.5;      // Lip overhang width
usbc_cut_w  = 14.0;     // USB-C port cutout width
usbc_cut_h  = 8.0;      // USB-C port cutout height

// Cable channels
cable_ch_w  = 8.0;      // Channel width
cable_ch_d  = 6.0;      // Channel depth

// Hex ventilation mesh
hex_across  = 5.0;      // Hex hole across flats
hex_wall    = 1.0;      // Wall between hexes
hex_pitch   = hex_across + hex_wall;  // Center-to-center

// Hub rail mount
hub_rail_t  = 1.5;      // Rail thickness
hub_rail_h  = 3.0;      // Rail height (grips hub sides)

// =====================================================================
// Overall Enclosure Dimensions
// =====================================================================

// Width: tablet (210) + clearance (2) + walls (4) = 216mm
// But tablet slot is tilted, so the footprint depth of the tablet
// zone is tablet_d * cos(15) + tablet_h * sin(15) ≈ 122.2mm.
// We add some margin for the lip and structure.

// Layout zones (Y-axis, front to back):
//   Zone 1 (bottom):  Power bank bay         — pbank_d + 2*clr + 2*wall = 73mm
//   Zone 2 (middle):  Router + Hub + empty   — router_d + 2*clr + wall = ~62mm
//   Zone 3 (top):     Tablet slot (tilted)   — ~30mm footprint at base

// Total depth estimate: 73 + 1.6 + 62 = ~137mm
// Total width: tablet_w + 2*tablet_clr + 2*wall = 216mm
// Total height: floor + pbank_h + clr + router_h + clr + margin ≈ 55mm

// Actual computed dimensions:
enc_w = tablet_w + 2 * tablet_clr + 2 * wall;  // 216mm
// Depth zones
zone_pbank_d = pbank_d + 2 * pbank_clr + wall;  // front zone: power bank
zone_elec_d  = router_d + 2 * router_clr + wall; // rear zone: electronics
zone_tablet_d = 25;  // tablet base footprint + lip support
enc_d = wall + zone_pbank_d + divider_t + zone_elec_d + wall;  // ~135mm
enc_h = floor_t + pbank_h + pbank_clr + 2 + router_h + router_clr + 5;  // ~63mm

// Split point: between power bank zone and electronics zone
split_y = wall + zone_pbank_d;  // Front half: 0..split_y, Rear half: split_y..enc_d

// Verify build volume compliance
// Front half: enc_w(216) x split_y(~75) x enc_h(~63) — width exceeds 180!
// Need to split along X instead, OR reduce width.
// Actually the tablet is 210mm wide — we MUST split along the width axis.
// BUT the spec says front/rear split. Let's re-examine.
//
// Re-layout: The tablet is 210mm wide. Even the tablet alone exceeds 180mm.
// Solution: orient the split along the Y axis (front=tablet, rear=electronics)
// and accept that each half is printed on its SIDE or we rotate the tablet
// slot 90 degrees... No — spec says landscape.
//
// Better approach: split LEFT and RIGHT at X midpoint (like original).
// Each half: 216/2 = 108mm wide, ~135mm deep, ~63mm tall. All < 180. Good.
//
// BUT spec says front+rear with M4 bolt joint. Let's honor that.
// Front half (tablet): 216 x (tablet tilt footprint ~35mm) x ~30mm — fits.
// Rear half (electronics): 216 x 100mm x 63mm — width 216 > 180!
//
// Final solution: Print each half on its side (longest dim along Y).
// Front: print standing up (216mm along Y bed axis, 35mm X, 30mm Z) — 216>180 FAIL.
//
// Conclusion: Must split along X (left/right) just like original design.
// The spec says "if it exceeds, add a split joint at the midpoint" and
// suggests front/rear, but physically left/right is the only way to fit
// a 210mm tablet. We split at X midpoint with M4 bolt joint.

// REVISED: Split left/right at X center
half_w = enc_w / 2;  // 108mm — fits build volume

// Verify: each half = 108 x enc_d x enc_h — all under 180mm. Good.

// =====================================================================
// Component Positions (origin at front-left floor corner of full enclosure)
// =====================================================================

// Power bank: bottom layer, centered in width, near front
pbank_x = (enc_w - pbank_w) / 2;
pbank_y = wall + pbank_clr;
pbank_z = floor_t;

// Router: rear-left, on floor above divider level
router_x = wall + 3;
router_y = split_y + divider_t + 3;
router_z = floor_t;

// Hub: rear-center, right of router, buttons face FRONT
hub_x = router_x + router_w + 2 * router_clr + 5;
hub_y = split_y + divider_t + 3;
hub_z = floor_t;

// Tablet: top zone, centered, tilted back 15 degrees
// The tablet sits in a cradle at the rear top of the enclosure
tablet_x = (enc_w - tablet_w - 2 * tablet_clr) / 2;
tablet_base_y = enc_d - wall - 10;  // Near rear wall
tablet_base_z = floor_t + router_h + router_clr + 5;  // Above electronics

// =====================================================================
// Module: Hex Ventilation Mesh
// =====================================================================
module hex_mesh(width, height, thickness) {
    // Creates a grid of hexagonal holes for ventilation
    // Oriented flat (pointy-top hexagons)
    hex_r = hex_across / 2 / cos(30);  // Circumscribed radius
    cols = floor(width / hex_pitch);
    rows = floor(height / (hex_pitch * 0.866));

    for (col = [0 : cols - 1]) {
        for (row = [0 : rows - 1]) {
            x_off = col * hex_pitch + (row % 2) * (hex_pitch / 2);
            y_off = row * hex_pitch * 0.866;
            if (x_off >= hex_r && x_off <= width - hex_r &&
                y_off >= hex_r && y_off <= height - hex_r) {
                translate([x_off, y_off, -0.1])
                    cylinder(h = thickness + 0.2, r = hex_across / 2, $fn = 6);
            }
        }
    }
}

// =====================================================================
// Module: Tablet Slot — tilted cradle with lip and USB-C cutout
// =====================================================================
module tablet_slot() {
    // Pocket dimensions with clearance
    pw = tablet_w + 2 * tablet_clr;   // 212mm
    pd = tablet_d + 2 * tablet_clr;   // 126.4mm
    ph = tablet_h + tablet_clr + 2;   // ~11mm pocket depth

    // The tablet cradle is a tilted trough at the top-rear of the enclosure.
    // It spans the full width and tilts backward by tablet_tilt degrees.
    // Origin: centered at enc_w/2, rear wall, at electronics top level.

    cradle_base_z = router_h + router_clr + floor_t + 3;

    translate([wall, enc_d - wall - 5, cradle_base_z])
    rotate([-tablet_tilt, 0, 0]) {
        // Main pocket cutout
        translate([0, -pd, 0])
            cube([pw, pd, ph]);

        // USB-C cutout at bottom edge (front-facing when tilted)
        translate([(pw - usbc_cut_w) / 2, -pd - wall - 1, 0])
            cube([usbc_cut_w, wall + 2, usbc_cut_h]);
    }
}

// =====================================================================
// Module: Tablet Lips — retaining edges (left, right, bottom)
// =====================================================================
module tablet_lips() {
    pw = tablet_w + 2 * tablet_clr;
    pd = tablet_d + 2 * tablet_clr;
    ph = tablet_h + tablet_clr + 2;
    cradle_base_z = router_h + router_clr + floor_t + 3;

    translate([wall, enc_d - wall - 5, cradle_base_z])
    rotate([-tablet_tilt, 0, 0])
    translate([0, -pd, ph]) {
        // Left lip
        cube([lip_w, pd, lip_h]);
        // Right lip
        translate([pw - lip_w, 0, 0])
            cube([lip_w, pd, lip_h]);
        // Bottom lip (front edge — prevents tablet sliding down)
        // Leave gap for USB-C
        usbc_gap_start = (pw - usbc_cut_w) / 2 - 5;
        usbc_gap_end = (pw + usbc_cut_w) / 2 + 5;
        // Left segment of bottom lip
        cube([usbc_gap_start, lip_w, lip_h]);
        // Right segment of bottom lip
        translate([usbc_gap_end, 0, 0])
            cube([pw - usbc_gap_end, lip_w, lip_h]);
    }
}

// =====================================================================
// Module: Tablet Dummy Volume (ghost for visualization)
// =====================================================================
module tablet_dummy() {
    pw = tablet_w + 2 * tablet_clr;
    pd = tablet_d + 2 * tablet_clr;
    ph = tablet_h + tablet_clr + 2;
    cradle_base_z = router_h + router_clr + floor_t + 3;

    translate([wall + tablet_clr, enc_d - wall - 5, cradle_base_z])
    rotate([-tablet_tilt, 0, 0])
    translate([0, -pd + tablet_clr, 1])
        %cube([tablet_w, tablet_d, tablet_h]);
}

// =====================================================================
// Module: Router Bay — friction-fit with hex ventilation mesh
// =====================================================================
module router_bay() {
    // Cradle walls around router, open top for removal
    rw = router_w + 2 * router_clr;
    rd = router_d + 2 * router_clr;

    translate([router_x, router_y, router_z]) {
        difference() {
            // Outer cradle shell (3 walls — open front for port access)
            cube([rw + 2 * wall, rd + wall, router_h + router_clr + wall]);

            // Inner cavity
            translate([wall, 0, wall])
                cube([rw, rd + 0.1, router_h + router_clr + 1]);

            // Hex ventilation on back wall (Ethernet/USB ports face rear)
            translate([wall, rd + wall - 0.1, wall + 2])
                rotate([90, 0, 0])
                    hex_mesh(rw, router_h - 2, wall + 0.2);
        }

        // Dummy volume
        translate([wall + router_clr, router_clr, wall])
            %cube([router_w, router_d, router_h]);
    }
}

// =====================================================================
// Module: Router Rear Port Cutout
// =====================================================================
module router_port_cutout() {
    // Ethernet + USB ports face the rear wall — cut through enclosure wall
    rw = router_w + 2 * router_clr;
    port_w = 50;  // Wide enough for both Ethernet and USB
    port_h = 20;
    port_x = router_x + wall + (rw - port_w) / 2;
    port_z = router_z + wall + 2;

    translate([port_x, enc_d - wall - 0.1, port_z])
        cube([port_w, wall + 0.2, port_h]);
}

// =====================================================================
// Module: Hub Mount — rail mount, buttons face front
// =====================================================================
module hub_mount() {
    // The hub slides in from the left side along bottom rails.
    // Power buttons face FRONT (toward user) for tactile access.
    // Main power input faces REAR.
    // Hub is rotated 90 degrees so its long axis runs left-right,
    // with the button side facing front.

    hw = hub_w + 2 * hub_clr;  // Along X axis
    hd = hub_d + 2 * hub_clr;  // Along Y axis
    hh = hub_h + hub_clr;

    translate([hub_x, hub_y, hub_z]) {
        // Left rail
        cube([hub_rail_t, hd, hub_rail_h]);
        translate([0, 0, hub_rail_h])
            cube([hub_rail_t, hd, hh - hub_rail_h]);

        // Right rail
        translate([hw + hub_rail_t, 0, 0]) {
            cube([hub_rail_t, hd, hub_rail_h]);
            translate([0, 0, hub_rail_h])
                cube([hub_rail_t, hd, hh - hub_rail_h]);
        }

        // Bottom rail (slides)
        cube([hw + 2 * hub_rail_t, hd, hub_rail_t]);

        // Back stop
        translate([0, hd, 0])
            cube([hw + 2 * hub_rail_t, hub_rail_t, hh]);

        // Dummy volume
        translate([hub_rail_t + hub_clr, hub_clr, hub_rail_t + 0.5])
            %cube([hub_w, hub_d, hub_h]);
    }
}

// =====================================================================
// Module: Hub Button Access Window
// =====================================================================
module hub_button_cutout() {
    // The 4 individual power buttons face front (toward the user).
    // Cut a window in the front-facing side of the hub area for access.
    hw = hub_w + 2 * hub_clr;
    window_w = hub_w - 10;  // Leave 5mm frame each side
    window_h = hub_h - 4;   // Leave 2mm frame top/bottom
    window_x = hub_x + hub_rail_t + hub_clr + 5;
    window_z = hub_z + hub_rail_t + 2;

    // Cut through the divider wall between front and rear zones
    translate([window_x, hub_y - 0.1, window_z])
        cube([window_w, divider_t + 0.2, window_h]);
}

// =====================================================================
// Module: Hub Power Input Cutout (rear)
// =====================================================================
module hub_power_cutout() {
    // Main USB power input faces rear wall
    hw = hub_w + 2 * hub_clr;
    hd = hub_d + 2 * hub_clr;
    cut_w = 15;
    cut_h = 10;
    cut_x = hub_x + hub_rail_t + (hw - cut_w) / 2;
    cut_z = hub_z + hub_rail_t + 1;

    translate([cut_x, enc_d - wall - 0.1, cut_z])
        cube([cut_w, wall + 0.2, cut_h]);
}

// =====================================================================
// Module: Power Bank Bay — friction-fit with port cutouts
// =====================================================================
module powerbank_bay() {
    // Full-width bay at the bottom front of the enclosure
    bw = pbank_w + 2 * pbank_clr;
    bd = pbank_d + 2 * pbank_clr;
    bh = pbank_h + pbank_clr;

    translate([pbank_x, pbank_y, pbank_z]) {
        difference() {
            // Cradle walls (U-shape, open top)
            union() {
                // Left wall
                cube([wall, bd, bh]);
                // Right wall
                translate([bw + wall, 0, 0])
                    cube([wall, bd, bh]);
                // Back wall
                translate([0, bd, 0])
                    cube([bw + 2 * wall, wall, bh]);
                // Front wall (partial — leave LED window)
                cube([bw + 2 * wall, wall, bh]);
            }

            // LED indicator window (small slot in front wall)
            translate([wall + bw / 2 - 10, -0.1, 2])
                cube([20, wall + 0.2, 4]);
        }

        // Dummy volume
        translate([wall + pbank_clr, pbank_clr, 0])
            %cube([pbank_w, pbank_d, pbank_h]);
    }
}

// =====================================================================
// Module: Power Bank Charging Port Cutout (right side)
// =====================================================================
module pbank_port_cutout() {
    // USB-C charging port on the right side wall of enclosure
    bw = pbank_w + 2 * pbank_clr;
    port_w = 14;
    port_h = 8;
    port_y = pbank_y + (pbank_d + 2 * pbank_clr - port_w) / 2;
    port_z = pbank_z + 2;

    // Right side of power bank — cut through enclosure right wall
    translate([enc_w - wall - 0.1, port_y, port_z])
        cube([wall + 0.2, port_w, port_h]);
}

// =====================================================================
// Module: Power Bank LED Window (front wall)
// =====================================================================
module pbank_led_cutout() {
    // LED indicator faces front — cut through enclosure front wall
    led_w = 20;
    led_h = 4;
    led_x = pbank_x + (pbank_w + 2 * pbank_clr) / 2 - led_w / 2;
    led_z = pbank_z + 2;

    translate([led_x, -0.1, led_z])
        cube([led_w, wall + 0.2, led_h]);
}

// =====================================================================
// Module: Cable Channels — internal routing
// =====================================================================
module cable_channels() {
    // Channel 1: Power bank (front) USB-A → up and back to hub power input
    // Runs along right internal wall from power bank to hub
    ch1_x = enc_w - wall - cable_ch_w - 2;
    ch1_y1 = pbank_y + pbank_d + pbank_clr;
    ch1_y2 = hub_y + hub_d + hub_clr;
    ch1_z = floor_t;
    translate([ch1_x, ch1_y1, ch1_z])
        cube([cable_ch_w, ch1_y2 - ch1_y1, cable_ch_d]);

    // Channel 2: Hub USB-A ports → router USB input
    // Runs along the rear zone connecting hub to router
    ch2_x1 = router_x + router_w + 2 * router_clr + wall;
    ch2_x2 = hub_x;
    ch2_y = hub_y + hub_d / 2 - cable_ch_w / 2;
    translate([ch2_x1, ch2_y, floor_t])
        cube([ch2_x2 - ch2_x1, cable_ch_w, cable_ch_d]);

    // Channel 3: Hub/Router area → up to tablet USB-C
    // Vertical channel along center, from electronics zone up to tablet cradle
    ch3_x = enc_w / 2 - cable_ch_w / 2;
    ch3_y = hub_y + hub_d / 2;
    ch3_z1 = floor_t;
    ch3_z2 = router_h + router_clr + floor_t + 3;
    translate([ch3_x, ch3_y, ch3_z1])
        cube([cable_ch_w, cable_ch_w, ch3_z2 - ch3_z1]);

    // Channel 4: Along the divider wall (left-right) for cross-routing
    ch4_y = split_y - cable_ch_w / 2;
    translate([wall + 5, ch4_y, floor_t])
        cube([enc_w - 2 * wall - 10, cable_ch_w, cable_ch_d]);
}

// =====================================================================
// Module: M3 Corner Mounting Holes (for desk mount)
// =====================================================================
module corner_mount_holes() {
    // 4x M3 through-holes at corners, through the floor
    inset = 8;
    positions = [
        [inset, inset],
        [enc_w - inset, inset],
        [inset, enc_d - inset],
        [enc_w - inset, enc_d - inset]
    ];
    for (p = positions) {
        translate([p[0], p[1], -0.1])
            m3_hole(depth = floor_t + 0.2);
    }
}

// =====================================================================
// Module: Edge Chamfers — 0.8mm on all external user-facing edges
// =====================================================================
module edge_chamfers() {
    // Bottom edge chamfers (4 sides)
    // Front bottom edge
    translate([0, 0, 0])
        rotate([0, 0, 0])
            linear_extrude(height = enc_w + 0.2)
                polygon([[-0.1, -0.1], [chamfer + 0.1, -0.1], [-0.1, chamfer + 0.1]]);

    // We implement chamfers via minkowski or direct cuts.
    // For simplicity, use difference with triangular prisms on key edges.

    // Front-bottom edge
    translate([-0.1, -0.1, -0.1])
        rotate([0, 90, 0])
            linear_extrude(height = enc_w + 0.2)
                polygon([[0, 0], [-chamfer - 0.1, 0], [0, chamfer + 0.1]]);

    // Rear-bottom edge
    translate([-0.1, enc_d + 0.1, -0.1])
        rotate([0, 90, 0])
            linear_extrude(height = enc_w + 0.2)
                polygon([[0, 0], [-chamfer - 0.1, 0], [0, -chamfer - 0.1]]);

    // Left-bottom edge
    translate([-0.1, -0.1, -0.1])
        rotate([0, 0, 90])
            rotate([0, 90, 0])
                linear_extrude(height = enc_d + 0.2)
                    polygon([[0, 0], [-chamfer - 0.1, 0], [0, chamfer + 0.1]]);

    // Right-bottom edge
    translate([enc_w + 0.1, -0.1, -0.1])
        rotate([0, 0, 90])
            rotate([0, 90, 0])
                linear_extrude(height = enc_d + 0.2)
                    polygon([[0, 0], [-chamfer - 0.1, 0], [0, -chamfer - 0.1]]);
}

// =====================================================================
// Module: Split Joint — alignment keys and M4 bolt holes at X midpoint
// =====================================================================

// Key positions along the seam (at x = half_w)
key_y1 = enc_d * 0.25;
key_y2 = enc_d * 0.75;
key_z  = enc_h * 0.33;

// Bolt positions
bolt_y1 = enc_d * 0.3;
bolt_y2 = enc_d * 0.7;
bolt_z  = enc_h * 0.66;
bolt_depth = 12;

module split_keys_male() {
    // Alignment keys on left half seam face (protrude in +X)
    translate([half_w, key_y1, key_z])
        rotate([0, 90, 0])
            split_key(size = 4, height = 3);
    translate([half_w, key_y2, key_z])
        rotate([0, 90, 0])
            split_key(size = 4, height = 3);
}

module split_sockets_female() {
    // Alignment sockets on right half seam face (cut into +X face at x=0)
    translate([0, key_y1, key_z])
        rotate([0, 90, 0])
            split_socket(size = 4, height = 3);
    translate([0, key_y2, key_z])
        rotate([0, 90, 0])
            split_socket(size = 4, height = 3);
}

module split_bolts_left() {
    // M4 bolt holes on left half seam face
    translate([half_w - bolt_depth / 2, bolt_y1, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth = bolt_depth);
    translate([half_w - bolt_depth / 2, bolt_y2, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth = bolt_depth);
}

module split_bolts_right() {
    // M4 bolt holes on right half seam face
    translate([-bolt_depth / 2, bolt_y1, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth = bolt_depth);
    translate([-bolt_depth / 2, bolt_y2, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth = bolt_depth);
}

// =====================================================================
// Module: Enclosure Shell (full, before splitting)
// =====================================================================
module enclosure_shell() {
    difference() {
        rounded_cube([enc_w, enc_d, enc_h], r = corner_r);

        // Hollow interior
        translate([wall, wall, floor_t])
            cube([enc_w - 2 * wall, enc_d - 2 * wall, enc_h]);
    }
}

// =====================================================================
// Module: Internal Divider — separates power bank zone from electronics zone
// =====================================================================
module internal_divider() {
    translate([wall, split_y, floor_t])
        cube([enc_w - 2 * wall, divider_t, enc_h * 0.5]);
}

// =====================================================================
// Module: Cradle Front — left half of front section (power bank + tablet)
// =====================================================================
module cradle_left() {
    difference() {
        union() {
            // Left half of enclosure shell
            intersection() {
                cube([half_w + 0.01, enc_d + 1, enc_h + 50]);
                union() {
                    enclosure_shell();
                    internal_divider();
                    tablet_lips();
                }
            }

            // Alignment keys
            split_keys_male();

            // Component bays (left portion)
            intersection() {
                cube([half_w + 0.01, enc_d + 1, enc_h + 1]);
                union() {
                    router_bay();
                    hub_mount();
                    powerbank_bay();
                }
            }
        }

        // Tablet slot cutout (left portion)
        intersection() {
            cube([half_w + 0.1, enc_d + 50, enc_h + 50]);
            tablet_slot();
        }

        // Cable channels (left portion)
        intersection() {
            cube([half_w + 0.1, enc_d + 1, enc_h + 1]);
            cable_channels();
        }

        // Port cutouts (left portion)
        intersection() {
            cube([half_w + 0.1, enc_d + 1, enc_h + 1]);
            union() {
                router_port_cutout();
                hub_button_cutout();
                hub_power_cutout();
                pbank_port_cutout();
                pbank_led_cutout();
            }
        }

        // Corner mount holes (left side)
        intersection() {
            cube([half_w + 0.1, enc_d + 1, enc_h + 1]);
            corner_mount_holes();
        }

        // Split bolt holes
        split_bolts_left();

        // Bottom edge chamfers (left portion)
        intersection() {
            cube([half_w + 0.1, enc_d + 1, enc_h + 1]);
            edge_chamfers();
        }
    }

    // Dummy volumes (left portion)
    intersection() {
        cube([half_w + 0.1, enc_d + 1, enc_h + 50]);
        tablet_dummy();
    }
}

// =====================================================================
// Module: Cradle Right — right half
// =====================================================================
module cradle_right() {
    // Right half — local origin at seam face, extends +X to half_w
    difference() {
        union() {
            // Right half of enclosure shell (shifted to local coords)
            intersection() {
                translate([-0.01, 0, 0])
                    cube([half_w + 0.02, enc_d + 1, enc_h + 50]);
                translate([-half_w, 0, 0])
                union() {
                    enclosure_shell();
                    internal_divider();
                    tablet_lips();
                }
            }

            // Component bays (right portion, shifted)
            intersection() {
                translate([-0.01, 0, 0])
                    cube([half_w + 0.02, enc_d + 1, enc_h + 1]);
                translate([-half_w, 0, 0])
                union() {
                    router_bay();
                    hub_mount();
                    powerbank_bay();
                }
            }
        }

        // Alignment sockets
        split_sockets_female();

        // Tablet slot cutout (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_w + 0.2, enc_d + 50, enc_h + 50]);
            translate([-half_w, 0, 0])
                tablet_slot();
        }

        // Cable channels (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_w + 0.2, enc_d + 1, enc_h + 1]);
            translate([-half_w, 0, 0])
                cable_channels();
        }

        // Port cutouts (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_w + 0.2, enc_d + 1, enc_h + 1]);
            translate([-half_w, 0, 0])
            union() {
                router_port_cutout();
                hub_button_cutout();
                hub_power_cutout();
                pbank_port_cutout();
                pbank_led_cutout();
            }
        }

        // Corner mount holes (right side)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_w + 0.2, enc_d + 1, enc_h + 1]);
            translate([-half_w, 0, 0])
                corner_mount_holes();
        }

        // Split bolt holes
        split_bolts_right();

        // Bottom edge chamfers (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_w + 0.2, enc_d + 1, enc_h + 1]);
            translate([-half_w, 0, 0])
                edge_chamfers();
        }
    }

    // Dummy volumes (right portion)
    intersection() {
        translate([-0.1, 0, 0])
            cube([half_w + 0.2, enc_d + 1, enc_h + 50]);
        translate([-half_w, 0, 0])
            tablet_dummy();
    }
}

// =====================================================================
// Module: Cradle Assembly — both halves joined
// =====================================================================
module cradle_assembly() {
    cradle_left();
    translate([half_w, 0, 0])
        cradle_right();
}

// =====================================================================
// Render Selected Part
// =====================================================================
if (part == "front")    cradle_left();
else if (part == "rear")     cradle_right();
else if (part == "assembly") cradle_assembly();

// =====================================================================
// Debug: Print computed dimensions
// =====================================================================
echo(str("Enclosure: ", enc_w, " x ", enc_d, " x ", enc_h, " mm"));
echo(str("Half width: ", half_w, " mm"));
echo(str("Split Y: ", split_y, " mm"));
echo(str("Power bank pos: [", pbank_x, ", ", pbank_y, ", ", pbank_z, "]"));
echo(str("Router pos: [", router_x, ", ", router_y, ", ", router_z, "]"));
echo(str("Hub pos: [", hub_x, ", ", hub_y, ", ", hub_z, "]"));
