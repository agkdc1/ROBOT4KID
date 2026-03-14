// Cockpit Console Cradle — Galaxy Tab A 8.0 (2019) + USB Gamepad
// Split into left and right halves for Bambu A1 Mini build volume
// CONSOLE_WIDTH (270mm) exceeds 180mm, so halves join at center line

use <../libs/common.scad>
use <../libs/m3_hardware.scad>
use <../libs/m4_hardware.scad>

// --- Console Dimensions (from common.scad) ---
// CONSOLE_WIDTH = 270, CONSOLE_DEPTH = 180, CONSOLE_HEIGHT = 60

// --- Tablet Dimensions (Galaxy Tab A 8.0 2019) ---
tablet_w = 210;                     // Width
tablet_d = 124;                     // Depth
tablet_h = 8;                       // Thickness
tablet_tol = 0.2;                   // Print tolerance per side
recess_w = tablet_w + 2 * tablet_tol;   // 210.4mm
recess_d = tablet_d + 2 * tablet_tol;   // 124.4mm
recess_h = tablet_h + 2 * tablet_tol;   // 8.4mm -> use 10mm pocket
pocket_depth = 10;                  // Recessed pocket depth
lip_h = 2;                         // Retaining lip height above tablet
tablet_angle = 15;                  // Viewing angle (degrees)

// --- Gamepad Dock ---
gamepad_w = 80;                     // Dock width
gamepad_d = 50;                     // Dock depth
gamepad_channel_w = 60;             // Friction-fit channel width
gamepad_channel_d = 35;             // Channel depth
gamepad_channel_h = 6;              // Channel depth (vertical)
cable_channel_w = 10;               // Cable routing channel width
cable_channel_h = 5;                // Cable routing channel depth

// --- Structural ---
wall = 1.6;                         // Wall thickness
half_width = CONSOLE_WIDTH / 2;     // 135mm per half (< 180mm build limit)

// --- Split Joint ---
key_size = 4;                       // Alignment key diameter
key_height = 3;                     // Alignment key height
bolt_depth = 10;                    // M4 bolt hole depth

// --- Rubber Feet ---
foot_dia = 8;                       // Rubber foot recess diameter
foot_depth = 2;                     // Rubber foot recess depth

// --- Ventilation ---
vent_count = 8;                     // Number of vent slots
vent_w = 3;                         // Vent slot width
vent_h = 15;                        // Vent slot height

// --- Cable Management ---
cable_mgmt_w = 12;                  // Back cable channel width
cable_mgmt_h = 8;                   // Back cable channel depth
zip_slot_w = 4;                     // Zip-tie slot width
zip_slot_d = 2;                     // Zip-tie slot thickness
zip_slot_h = 3;                     // Zip-tie slot depth into wall

// --- M3 Accessory Mount ---
m3_insert_depth = 6;                // Threaded insert hole depth
m3_mount_z1 = CONSOLE_HEIGHT * 0.3; // Lower accessory hole
m3_mount_z2 = CONSOLE_HEIGHT * 0.7; // Upper accessory hole
m3_mount_y_inset = 10;              // Inset from front/back

// --- Part Selector ---
// Set via CLI: -D 'part="left"'
part = "assembly";  // "left" | "right" | "assembly"

$fn = 64;

// =====================================================
// Modules
// =====================================================

module cradle_base_half() {
    // One half of the outer shell (left or right)
    // Origin at the split seam edge, extends in +X direction
    difference() {
        rounded_cube([half_width, CONSOLE_DEPTH, CONSOLE_HEIGHT], r=3);

        // Hollow interior
        translate([wall, wall, wall])
            cube([half_width - wall, CONSOLE_DEPTH - 2 * wall, CONSOLE_HEIGHT]);
    }
}

module tablet_cradle_cutout() {
    // Angled recess for the tablet, centered on full console width
    // Called relative to the full console coordinate system
    tablet_x = (CONSOLE_WIDTH - recess_w) / 2;
    tablet_y = CONSOLE_DEPTH - recess_d - 20;  // 20mm from back wall

    translate([tablet_x, tablet_y, CONSOLE_HEIGHT - pocket_depth])
    rotate([tablet_angle, 0, 0]) {
        // Tablet pocket (open at bottom/USB-C side)
        translate([-1, 0, 0])
            cube([recess_w + 2, recess_d + 10, pocket_depth + lip_h + 5]);

        // Re-add retaining lips by subtracting slightly less on 3 sides
        // (Lips are created in the positive module below)
    }
}

module tablet_pocket_shape() {
    // The full pocket carved into the cradle for the tablet
    // Coordinate system: full console, origin at [0,0,0]
    tablet_x = (CONSOLE_WIDTH - recess_w) / 2;
    tablet_y = CONSOLE_DEPTH - recess_d - 20;

    translate([tablet_x, tablet_y, CONSOLE_HEIGHT - pocket_depth])
    rotate([tablet_angle, 0, 0]) {
        // Main pocket
        cube([recess_w, recess_d, pocket_depth]);

        // Extended opening at bottom for USB-C port access
        translate([recess_w * 0.3, -5, 0])
            cube([recess_w * 0.4, 10, pocket_depth]);
    }
}

module tablet_lips() {
    // Retaining lips on left, right, and top sides of the pocket
    // Coordinate system: full console
    tablet_x = (CONSOLE_WIDTH - recess_w) / 2;
    tablet_y = CONSOLE_DEPTH - recess_d - 20;
    lip_inset = 1.5;  // How far lip extends over tablet

    translate([tablet_x, tablet_y, CONSOLE_HEIGHT - pocket_depth])
    rotate([tablet_angle, 0, 0])
    translate([0, 0, pocket_depth]) {
        // Left lip
        cube([lip_inset, recess_d, lip_h]);
        // Right lip
        translate([recess_w - lip_inset, 0, 0])
            cube([lip_inset, recess_d, lip_h]);
        // Top lip (back edge)
        translate([0, recess_d - lip_inset, 0])
            cube([recess_w, lip_inset, lip_h]);
        // Bottom edge: OPEN for USB-C access
    }
}

module gamepad_dock() {
    // Flat area with friction-fit channel, in front of tablet
    // Coordinate system: full console
    dock_x = (CONSOLE_WIDTH - gamepad_w) / 2;
    dock_y = 15;  // Near front edge

    // Channel cutout
    translate([
        (CONSOLE_WIDTH - gamepad_channel_w) / 2,
        dock_y + (gamepad_d - gamepad_channel_d) / 2,
        CONSOLE_HEIGHT - gamepad_channel_h
    ])
        cube([gamepad_channel_w, gamepad_channel_d, gamepad_channel_h + 0.1]);

    // Cable routing channel from gamepad to tablet USB port
    translate([
        CONSOLE_WIDTH / 2 - cable_channel_w / 2,
        dock_y + gamepad_d,
        CONSOLE_HEIGHT - cable_channel_h
    ])
        cube([cable_channel_w, CONSOLE_DEPTH - recess_d - 20 - dock_y - gamepad_d, cable_channel_h + 0.1]);
}

module cable_management_channel() {
    // Channel along the back wall for power/USB cables
    // Coordinate system: full console
    translate([wall + 5, CONSOLE_DEPTH - wall - cable_mgmt_w, CONSOLE_HEIGHT - cable_mgmt_h])
        cube([CONSOLE_WIDTH - 2 * wall - 10, cable_mgmt_w, cable_mgmt_h + 0.1]);
}

module zip_tie_slots() {
    // Zip-tie slots along the back cable channel
    // Coordinate system: full console
    slot_count = 5;
    spacing = (CONSOLE_WIDTH - 2 * wall - 20) / (slot_count - 1);

    for (i = [0 : slot_count - 1]) {
        translate([wall + 10 + i * spacing, CONSOLE_DEPTH - wall - 0.1, CONSOLE_HEIGHT - cable_mgmt_h - zip_slot_h])
            cube([zip_slot_w, wall + 0.2, zip_slot_h]);
    }
}

module ventilation_slots() {
    // Vent slots on the back wall
    // Coordinate system: full console
    slot_spacing = (CONSOLE_WIDTH - 2 * wall - 20) / (vent_count - 1);
    vent_z = (CONSOLE_HEIGHT - vent_h) / 2;

    for (i = [0 : vent_count - 1]) {
        translate([wall + 10 + i * slot_spacing, CONSOLE_DEPTH - wall - 0.1, vent_z])
            cube([vent_w, wall + 0.2, vent_h]);
    }
}

module rubber_feet() {
    // 4x rubber foot recesses on the bottom corners
    // Coordinate system: full console
    inset = 15;
    positions = [
        [inset,                    inset],
        [CONSOLE_WIDTH - inset,    inset],
        [inset,                    CONSOLE_DEPTH - inset],
        [CONSOLE_WIDTH - inset,    CONSOLE_DEPTH - inset]
    ];

    for (p = positions)
        translate([p[0], p[1], -0.1])
            cylinder(h=foot_depth + 0.1, d=foot_dia);
}

module m3_accessory_holes_side(x_pos) {
    // Two M3 threaded insert holes on one side wall
    translate([x_pos, m3_mount_y_inset, m3_mount_z1])
        rotate([0, 90, 0])
            m3_hole(depth=m3_insert_depth);
    translate([x_pos, CONSOLE_DEPTH - m3_mount_y_inset, m3_mount_z2])
        rotate([0, 90, 0])
            m3_hole(depth=m3_insert_depth);
}

module split_joint_features_male() {
    // Alignment keys on the seam face (added to left half)
    key_y1 = CONSOLE_DEPTH * 0.25;
    key_y2 = CONSOLE_DEPTH * 0.75;
    key_z = CONSOLE_HEIGHT * 0.33;

    translate([half_width, key_y1, key_z])
        rotate([0, 90, 0])
            split_key(size=key_size, height=key_height);
    translate([half_width, key_y2, key_z])
        rotate([0, 90, 0])
            split_key(size=key_size, height=key_height);
}

module split_joint_features_female() {
    // Alignment sockets on the seam face (cut from right half)
    // Right half origin is at the seam, so sockets are at x=0
    key_y1 = CONSOLE_DEPTH * 0.25;
    key_y2 = CONSOLE_DEPTH * 0.75;
    key_z = CONSOLE_HEIGHT * 0.33;

    translate([0, key_y1, key_z])
        rotate([0, 90, 0])
            split_socket(size=key_size, height=key_height);
    translate([0, key_y2, key_z])
        rotate([0, 90, 0])
            split_socket(size=key_size, height=key_height);
}

module split_bolt_holes_left() {
    // M4 bolt holes on the left half seam face
    bolt_y1 = CONSOLE_DEPTH * 0.25;
    bolt_y2 = CONSOLE_DEPTH * 0.75;
    bolt_z = CONSOLE_HEIGHT * 0.66;

    translate([half_width - bolt_depth / 2, bolt_y1, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
    translate([half_width - bolt_depth / 2, bolt_y2, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
}

module split_bolt_holes_right() {
    // M4 bolt holes on the right half seam face
    bolt_y1 = CONSOLE_DEPTH * 0.25;
    bolt_y2 = CONSOLE_DEPTH * 0.75;
    bolt_z = CONSOLE_HEIGHT * 0.66;

    translate([-bolt_depth / 2, bolt_y1, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
    translate([-bolt_depth / 2, bolt_y2, bolt_z])
        rotate([0, 90, 0])
            m4_hole(depth=bolt_depth);
}

// =====================================================
// Half Assemblies
// =====================================================

module console_left() {
    difference() {
        union() {
            cradle_base_half();
            // Alignment keys (protrude from seam face)
            split_joint_features_male();
        }

        // Tablet pocket (left portion: full console x=0..135)
        intersection() {
            translate([0, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 50, CONSOLE_HEIGHT + 50]);
            tablet_pocket_shape();
        }

        // Gamepad dock (left portion)
        intersection() {
            cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            gamepad_dock();
        }

        // Cable management channel (left portion)
        intersection() {
            cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            cable_management_channel();
        }

        // Zip-tie slots (left portion)
        intersection() {
            cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            zip_tie_slots();
        }

        // Ventilation slots (left portion)
        intersection() {
            cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            ventilation_slots();
        }

        // Rubber feet (left side)
        intersection() {
            cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            rubber_feet();
        }

        // M3 accessory holes on left outer wall
        m3_accessory_holes_side(-0.1);

        // Split bolt holes
        split_bolt_holes_left();
    }

    // Tablet retaining lips (left portion)
    intersection() {
        cube([half_width, CONSOLE_DEPTH + 50, CONSOLE_HEIGHT + 50]);
        tablet_lips();
    }
}

module console_right() {
    // Right half — origin shifted so seam is at x=0, extends to +half_width
    difference() {
        union() {
            cradle_base_half();
        }

        // Alignment sockets (cut into seam face)
        split_joint_features_female();

        // Tablet pocket (right portion: full console x=135..270, shifted to local coords)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 50, CONSOLE_HEIGHT + 50]);
            translate([-half_width, 0, 0])
                tablet_pocket_shape();
        }

        // Gamepad dock (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                gamepad_dock();
        }

        // Cable management channel (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                cable_management_channel();
        }

        // Zip-tie slots (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                zip_tie_slots();
        }

        // Ventilation slots (right portion)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                ventilation_slots();
        }

        // Rubber feet (right side)
        intersection() {
            translate([-0.1, 0, 0])
                cube([half_width + 0.1, CONSOLE_DEPTH + 10, CONSOLE_HEIGHT + 10]);
            translate([-half_width, 0, 0])
                rubber_feet();
        }

        // M3 accessory holes on right outer wall
        translate([half_width, 0, 0])
            m3_accessory_holes_side(0);

        // Split bolt holes
        split_bolt_holes_right();
    }

    // Tablet retaining lips (right portion)
    intersection() {
        cube([half_width + 0.1, CONSOLE_DEPTH + 50, CONSOLE_HEIGHT + 50]);
        translate([-half_width, 0, 0])
            tablet_lips();
    }
}

module console_assembly() {
    console_left();
    translate([half_width, 0, 0])
        console_right();
}

// =====================================================
// Render selected part
// =====================================================
if (part == "left") console_left();
else if (part == "right") console_right();
else if (part == "assembly") console_assembly();
