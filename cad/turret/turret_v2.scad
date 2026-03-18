// M1A1 Abrams — Turret V2 Blockout (1/18 scale)
// 2-piece split (front + rear), 22mm foam ball firing mechanism
// Blockout: simple primitives only, no fillets/chamfers
//
// Real turret: 5500 x 3250 x 800mm
// 1/18 scale:  306  x 181  x 44mm
// Split: front 153mm + rear 153mm, joined with M3 bolts

$fn = 32;

// ============================================================
// PARAMETERS
// ============================================================

// --- Overall turret ---
turret_length = 306;
turret_width  = 181;
turret_height = 44;
wall = 2.5;
floor_t = 2.0;

// Split
split_y = turret_length / 2;  // 153mm each half

// --- Turret ring ---
ring_od = 40;
ring_clearance = 0.2;  // per side
ring_height = 8;

// --- Barrel ---
barrel_od = 25;          // outer tube
barrel_id = 23;          // 22mm ball + 1mm clearance
barrel_length = 150;     // extends forward from turret face
barrel_wall_t = (barrel_od - barrel_id) / 2;

// --- Trunnion (barrel pivot) ---
trunnion_width = 40;
trunnion_height = 30;
trunnion_depth = 20;
trunnion_bore = barrel_od + 0.4;  // barrel passes through

// --- Magazine (vertical tube for 22mm balls) ---
mag_od = 29;             // 25mm ID + 2x2mm wall
mag_id = 25;             // fits 22mm ball with clearance
mag_height = 90;         // holds ~3-4 balls stacked (22mm each)
mag_lid_height = 5;

// --- Chamber (connects magazine bottom to barrel bore) ---
chamber_length = 30;
chamber_id = 23;         // same as barrel bore
chamber_od = 27;

// --- MG90S Servo dimensions ---
servo_w = 22.5;
servo_d = 12.0;
servo_h = 35.5;          // including horn

// --- ESP32-CAM + MB ---
cam_w = 40;
cam_d = 27;
cam_h = 25;

// --- ToF sensor (VL53L1X) ---
tof_w = 13;
tof_d = 18;
tof_h = 4;

// --- PCA9685 servo driver ---
pca_w = 62.5;
pca_d = 25.4;
pca_h = 15;

// --- Slip ring ---
slip_ring_dia = 22;
slip_ring_h = 15;

// --- Wago 221-415 ---
wago_w = 20;
wago_d = 13;
wago_h = 16;

// --- M3 bolt holes for split join ---
m3_hole = 3.4;
m3_head = 6.0;
bolt_count = 4;  // bolts along split line

// --- Part selector ---
// "assembly", "front", "rear", "barrel", "magazine"
part = "assembly";

// ============================================================
// UTILITY MODULES
// ============================================================

module rounded_cube(size, r=2) {
    hull() {
        for (x = [r, size[0]-r])
            for (y = [r, size[1]-r])
                translate([x, y, 0])
                    cylinder(h=size[2], r=r);
    }
}

// ============================================================
// TURRET SHELL (full, before split)
// ============================================================

module turret_shell_full() {
    // Outer shell — simple box with rounded edges
    difference() {
        // Outer body
        rounded_cube([turret_width, turret_length, turret_height], r=3);

        // Hollow interior
        translate([wall, wall, floor_t])
            rounded_cube([
                turret_width - 2*wall,
                turret_length - 2*wall,
                turret_height  // open top
            ], r=2);

        // Turret ring hole through floor (center of turret)
        translate([turret_width/2, turret_length/2, -1])
            cylinder(d=ring_od + ring_clearance*2, h=floor_t+2);

        // Camera window (front face)
        translate([turret_width/2 - cam_w/2, -1, floor_t + 5])
            cube([cam_w, wall+2, cam_h - 5]);

        // ToF aperture (front face, below camera window)
        translate([turret_width/2, -1, floor_t + 2])
            rotate([-90, 0, 0])
                cylinder(d=8, h=wall+2);

        // Barrel hole (front face)
        translate([turret_width/2, -1, turret_height/2])
            rotate([-90, 0, 0])
                cylinder(d=barrel_od + 1, h=wall+2);

        // Magazine refill port (top, rear area)
        translate([turret_width/2, turret_length * 0.65, turret_height - 1])
            cylinder(d=mag_od + 1, h=2);

        // Split line bolt holes (M3, along Y = split_y)
        for (i = [0:bolt_count-1]) {
            bx = turret_width * (i + 1) / (bolt_count + 1);
            // Vertical bolt holes at split line
            translate([bx, split_y, -1])
                cylinder(d=m3_hole, h=turret_height + 2);
        }
    }

    // Turret ring (protrudes below)
    translate([turret_width/2, turret_length/2, -ring_height])
        difference() {
            cylinder(d=ring_od, h=ring_height);
            translate([0, 0, -1])
                cylinder(d=ring_od - 6, h=ring_height + 2);
        }
}

// ============================================================
// TRUNNION BLOCK (barrel pivot mount)
// ============================================================

module trunnion_block() {
    // Sits at front-center of turret interior, barrel passes through
    translate([turret_width/2 - trunnion_width/2, wall, floor_t])
        difference() {
            cube([trunnion_width, trunnion_depth, trunnion_height]);
            // Barrel bore
            translate([trunnion_width/2, -1, trunnion_height/2])
                rotate([-90, 0, 0])
                    cylinder(d=trunnion_bore, h=trunnion_depth+2);
            // Tilt servo pocket (side mount)
            translate([-1, trunnion_depth/2 - servo_d/2, trunnion_height/2 - servo_h/2])
                cube([servo_w + 1, servo_d, servo_h]);
        }
}

// ============================================================
// BARREL V2 (23mm bore tube)
// ============================================================

module barrel_v2() {
    difference() {
        cylinder(d=barrel_od, h=barrel_length);
        translate([0, 0, -1])
            cylinder(d=barrel_id, h=barrel_length + 2);
    }
    // Bayonet ring at breech end
    translate([0, 0, 0])
        difference() {
            cylinder(d=barrel_od + 4, h=5);
            translate([0, 0, -1])
                cylinder(d=barrel_id, h=7);
        }
}

// ============================================================
// MAGAZINE (vertical ball stack)
// ============================================================

module magazine() {
    difference() {
        // Outer tube
        cylinder(d=mag_od, h=mag_height);
        // Inner bore
        translate([0, 0, -1])
            cylinder(d=mag_id, h=mag_height + 2);
    }
    // Refill lid flange at top
    translate([0, 0, mag_height])
        difference() {
            cylinder(d=mag_od + 6, h=mag_lid_height);
            translate([0, 0, -1])
                cylinder(d=mag_id, h=mag_lid_height + 2);
        }
}

// ============================================================
// LOADER MECHANISM (servo gate at magazine bottom)
// ============================================================

module loader_mechanism() {
    // Servo mount bracket
    color("orange", 0.6) {
        // Servo body (ghost)
        translate([-servo_w/2, -servo_d/2, 0])
            cube([servo_w, servo_d, servo_h]);
    }
    // Gate plate (blocks/opens magazine bottom)
    color("yellow", 0.6)
        translate([-15, -2, servo_h - 5])
            cube([30, 4, 5]);

    // Gate channel (the slot the gate slides in)
    color("gray", 0.3)
        translate([-mag_id/2 - 2, -3, -2])
            cube([mag_id + 4, 6, 2]);
}

// ============================================================
// STRIKER MECHANISM (servo kicker arm)
// ============================================================

module striker_mechanism() {
    // Servo mount
    color("red", 0.6) {
        translate([-servo_w/2, -servo_d/2, 0])
            cube([servo_w, servo_d, servo_h]);
    }
    // Kicker arm (flat paddle)
    color("pink", 0.6)
        translate([0, -1.5, servo_h - 3])
            cube([35, 3, 6]);  // extends to push ball

    // Chamber tube (connects magazine to barrel)
    color("gray", 0.4)
        translate([25, 0, servo_h - 3])
            rotate([0, 90, 0])
                difference() {
                    cylinder(d=chamber_od, h=chamber_length);
                    translate([0, 0, -1])
                        cylinder(d=chamber_id, h=chamber_length + 2);
                }
}

// ============================================================
// TURRET ELECTRONICS (ghost volumes)
// ============================================================

module turret_electronics() {
    // ESP32-CAM + MB — front left, behind camera window
    color("green", 0.4)
        translate([turret_width/2 - cam_w/2, wall + 2, floor_t])
            cube([cam_w, cam_d, cam_h]);

    // ToF sensor — front center, below camera
    color("cyan", 0.4)
        translate([turret_width/2 - tof_w/2, wall + 2, floor_t])
            cube([tof_w, tof_d, tof_h]);

    // PCA9685 servo driver — center, flat on floor
    color("blue", 0.4)
        translate([turret_width/2 - pca_w/2, turret_length/2 - pca_d/2, floor_t])
            cube([pca_w, pca_d, pca_h]);

    // Slip ring top — centered at turret ring
    color("purple", 0.4)
        translate([turret_width/2, turret_length/2, floor_t])
            cylinder(d=slip_ring_dia, h=slip_ring_h);

    // Wago connectors (4x) — rear left quadrant
    for (i = [0:3]) {
        color("orange", 0.4)
            translate([
                wall + 5 + (i % 2) * (wago_w + 5),
                turret_length * 0.7 + floor(i / 2) * (wago_d + 5),
                floor_t
            ])
                cube([wago_w, wago_d, wago_h]);
    }
}

// ============================================================
// SERVO GHOST VOLUMES
// ============================================================

module servo_ghosts() {
    // Tilt servo — at trunnion, right side
    color("orange", 0.5)
        translate([turret_width/2 + trunnion_width/2 + 2, wall + trunnion_depth/2 - servo_d/2, floor_t])
            cube([servo_w, servo_d, servo_h]);

    // Loader servo — next to magazine
    color("orange", 0.5)
        translate([turret_width/2 + mag_od/2 + 5, turret_length * 0.65 - servo_d/2, floor_t])
            cube([servo_w, servo_d, servo_h]);

    // Striker servo — behind chamber, right side
    color("red", 0.5)
        translate([turret_width/2 + 20, turret_length * 0.45 - servo_d/2, floor_t])
            cube([servo_w, servo_d, servo_h]);

    // Pan servo — below turret floor (centered)
    color("yellow", 0.5)
        translate([turret_width/2 - servo_w/2, turret_length/2 - servo_d/2, -ring_height - servo_h])
            cube([servo_w, servo_d, servo_h]);
}

// ============================================================
// FIRING SYSTEM ASSEMBLY (magazine + loader + striker + chamber)
// ============================================================

module firing_system() {
    // Magazine — vertical, rear-right area
    translate([turret_width/2, turret_length * 0.65, floor_t])
        magazine();

    // Loader mechanism — at magazine bottom
    translate([turret_width/2, turret_length * 0.65, floor_t])
        loader_mechanism();

    // Chamber tube — horizontal, connects magazine to barrel axis
    color("gray", 0.4)
        translate([turret_width/2, turret_length * 0.65, turret_height/2])
            rotate([0, 0, -90])
                rotate([0, 90, 0])
                    difference() {
                        cylinder(d=chamber_od, h=chamber_length);
                        translate([0, 0, -1])
                            cylinder(d=chamber_id, h=chamber_length + 2);
                    }

    // Striker mechanism — behind chamber
    translate([turret_width/2 + 25, turret_length * 0.50, floor_t])
        striker_mechanism();
}

// ============================================================
// SPLIT LINE FEATURES (bolt bosses + alignment keys)
// ============================================================

module split_bolt_bosses() {
    // Reinforcement bosses around bolt holes at split line
    for (i = [0:bolt_count-1]) {
        bx = turret_width * (i + 1) / (bolt_count + 1);
        translate([bx, split_y, floor_t])
            difference() {
                cylinder(d=m3_head + 4, h=turret_height - floor_t);
                translate([0, 0, -1])
                    cylinder(d=m3_hole, h=turret_height);
            }
    }
}

module split_alignment_keys() {
    // Alignment pins at split line (2 pins)
    key_d = 4;
    key_h = 4;
    for (x_pos = [turret_width * 0.25, turret_width * 0.75]) {
        // Male side (on front half)
        translate([x_pos, split_y, floor_t + 5])
            rotate([90, 0, 0])
                cylinder(d=key_d, h=key_h);
    }
}

// ============================================================
// TURRET FRONT (first print piece: Y = 0 to split_y)
// ============================================================

module turret_front() {
    intersection() {
        turret_shell_full();
        translate([-1, -ring_height - 1, -ring_height - 1])
            cube([turret_width + 2, split_y + ring_height + 1, turret_height + ring_height + 2]);
    }
    // Trunnion (in front half)
    trunnion_block();
    // Alignment keys (male)
    split_alignment_keys();
}

// ============================================================
// TURRET REAR (second print piece: Y = split_y to turret_length)
// ============================================================

module turret_rear() {
    intersection() {
        turret_shell_full();
        translate([-1, split_y, -ring_height - 1])
            cube([turret_width + 2, split_y + 1, turret_height + ring_height + 2]);
    }
    // Alignment sockets (female, with tolerance)
    key_d = 4;
    key_h = 4;
    tol = 0.2;
    for (x_pos = [turret_width * 0.25, turret_width * 0.75]) {
        difference() {
            translate([x_pos, split_y, floor_t + 5])
                rotate([90, 0, 0])
                    cylinder(d=key_d + 2 + tol*2, h=2);
            translate([x_pos, split_y + 0.1, floor_t + 5])
                rotate([90, 0, 0])
                    cylinder(d=key_d + tol*2, h=key_h + 0.2);
        }
    }
}

// ============================================================
// TURRET ASSEMBLY (everything together)
// ============================================================

module turret_assembly() {
    // Shell (full turret)
    color("tan", 0.5)
        turret_shell_full();

    // Trunnion
    color("sienna", 0.7)
        trunnion_block();

    // Barrel — extending forward from front face
    color("dimgray", 0.8)
        translate([turret_width/2, -barrel_length + 5, turret_height/2])
            rotate([-90, 0, 0])
                barrel_v2();

    // Firing system (magazine, loader, striker, chamber)
    firing_system();

    // Electronics ghost volumes
    turret_electronics();

    // Servo ghost volumes
    servo_ghosts();

    // Split line visualization
    color("red", 0.2)
        translate([0, split_y - 0.5, -ring_height])
            cube([turret_width, 1, turret_height + ring_height + 5]);
}

// ============================================================
// PART SELECTOR
// ============================================================

if (part == "assembly") {
    turret_assembly();
} else if (part == "front") {
    turret_front();
} else if (part == "rear") {
    // Rotate for printing: flat on bed
    turret_rear();
} else if (part == "barrel") {
    // Print standing up for round accuracy
    barrel_v2();
} else if (part == "magazine") {
    magazine();
}
