// =====================================================================
// Universal Modular Insert Standard — Tank Hull Inserts
// All functional components mount on removable inserts secured by M3 screws
// Insert drops into hull cavity, secured by 2-4x M3 bolts from above
// =====================================================================

$fn = 48;

// =====================================================================
// PARAMETERS
// =====================================================================

// --- Insert base plate ---
insert_wall    = 2.0;     // Insert wall thickness
insert_floor   = 1.6;     // Insert floor thickness
m3_hole        = 3.4;     // M3 clearance hole
m3_boss_od     = 7.0;     // Boss outer diameter
m3_nut_af      = 5.5;     // M3 nut across-flats
m3_nut_h       = 2.4;     // M3 nut height

// --- Component dimensions (from hardware_specs.yaml) ---
// DROK buck converter
drok_l = 46;  drok_w = 28;  drok_h = 14;
// 2-to-8 lever-nut
levernut_l = 40;  levernut_w = 20;  levernut_h = 18;
// Wago 221-415
wago_l = 20;  wago_w = 13;  wago_h = 16;
// L9110S motor driver
l9110s_l = 29;  l9110s_w = 23;  l9110s_h = 15;
// N20 motor
n20_dia = 12;  n20_len = 25;
// ESP32-CAM + MB
esp_l = 40;  esp_w = 27;  esp_h = 25;
// MPU-6050
mpu_l = 21;  mpu_w = 16;  mpu_h = 3;
// Slip ring
slip_dia = 22;  slip_h = 15;

// --- Insert sizes ---
// Power hub: holds DROK + lever-nut + 4x Wago
power_hub_l = 100;
power_hub_w = 60;
power_hub_h = 25;

// Drivetrain: holds N20 motor + L9110S driver
drive_l = 45;
drive_w = 35;
drive_h = 20;

// Part selector
part = "assembly";  // "power_hub" | "drivetrain" | "sensor" | "assembly"

// =====================================================================
// UTILITY
// =====================================================================

module m3_boss(h) {
    difference() {
        cylinder(d=m3_boss_od, h=h);
        translate([0, 0, -0.5])
            cylinder(d=m3_hole, h=h+1);
    }
}

module m3_nut_pocket(depth=m3_nut_h) {
    // Hex pocket for captive M3 nut
    translate([0, 0, -0.5])
        cylinder(d=m3_nut_af / cos(30), h=depth + 0.5, $fn=6);
}

module m3_mount_hole(depth=10) {
    // Through hole + nut pocket on bottom
    translate([0, 0, -0.5])
        cylinder(d=m3_hole, h=depth + 1);
    translate([0, 0, -0.5])
        m3_nut_pocket();
}

// =====================================================================
// POWER HUB INSERT
// Holds: DROK buck converter + 2-to-8 lever-nut + 4x Wago connectors
// Secured to hull center floor via 4x M3 bolts
// =====================================================================

module power_hub_insert() {
    color("DarkSlateGray", 0.8)
    difference() {
        union() {
            // Base tray
            cube([power_hub_l, power_hub_w, insert_floor]);

            // Perimeter walls
            // Left
            cube([power_hub_l, insert_wall, power_hub_h]);
            // Right
            translate([0, power_hub_w - insert_wall, 0])
                cube([power_hub_l, insert_wall, power_hub_h]);
            // Back
            cube([insert_wall, power_hub_w, power_hub_h]);
            // Front (partial, with wire exit)
            translate([power_hub_l - insert_wall, 0, 0])
                cube([insert_wall, power_hub_w, power_hub_h]);

            // DROK mount rails (2 parallel rails, component sits between)
            translate([5, insert_wall + 2, insert_floor])
                cube([drok_l + 2, 2, 3]);
            translate([5, insert_wall + 2 + drok_w + 2, insert_floor])
                cube([drok_l + 2, 2, 3]);

            // Lever-nut mount platform
            translate([5 + drok_l + 8, insert_wall + 2, insert_floor])
                cube([levernut_l + 2, levernut_w + 4, 2]);

            // M3 screw bosses (4 corners)
            for (pos = [[5, 5], [power_hub_l-5, 5],
                         [5, power_hub_w-5], [power_hub_l-5, power_hub_w-5]])
                translate([pos[0], pos[1], 0])
                    m3_boss(power_hub_h);
        }

        // M3 through-holes (for bolts from above)
        for (pos = [[5, 5], [power_hub_l-5, 5],
                     [5, power_hub_w-5], [power_hub_l-5, power_hub_w-5]])
            translate([pos[0], pos[1], -0.5])
                cylinder(d=m3_hole, h=power_hub_h + 1);

        // M3 nut traps on bottom
        for (pos = [[5, 5], [power_hub_l-5, 5],
                     [5, power_hub_w-5], [power_hub_l-5, power_hub_w-5]])
            translate([pos[0], pos[1], 0])
                m3_nut_pocket();

        // Wire exits (slots in front/back walls)
        translate([power_hub_l - insert_wall - 1, power_hub_w/2 - 5, insert_floor + 2])
            cube([insert_wall + 2, 10, 8]);
        translate([-1, power_hub_w/2 - 5, insert_floor + 2])
            cube([insert_wall + 2, 10, 8]);

        // Wago pockets (4x along right wall interior)
        for (i = [0:3])
            translate([8 + i * 22, power_hub_w - insert_wall - wago_w - 2, insert_floor + 1])
                cube([wago_l + 1, wago_w + 1, wago_h + 1]);
    }
}

module power_hub_ghosts() {
    // DROK (green)
    color("ForestGreen", 0.5)
        translate([6, insert_wall + 4, insert_floor + 3])
            cube([drok_l, drok_w, drok_h]);

    // Lever-nut (orange)
    color("DarkOrange", 0.5)
        translate([6 + drok_l + 9, insert_wall + 4, insert_floor + 2])
            cube([levernut_l, levernut_w, levernut_h]);

    // 4x Wago (yellow)
    for (i = [0:3])
        color("Gold", 0.5)
            translate([8.5 + i * 22, power_hub_w - insert_wall - wago_w - 1.5, insert_floor + 1.5])
                cube([wago_l, wago_w, wago_h]);
}

// =====================================================================
// DRIVETRAIN INSERT
// Holds: N20 motor + L9110S motor driver
// One per side, secured via 2x M3 bolts
// =====================================================================

module drivetrain_insert() {
    color("DimGray", 0.8)
    difference() {
        union() {
            // Base plate
            cube([drive_l, drive_w, insert_floor]);

            // Motor clamp cradle (U-shape)
            translate([5, drive_w/2, insert_floor]) {
                difference() {
                    cube([n20_len + 4, n20_dia + 6, n20_dia/2 + 4]);
                    translate([2, (n20_dia + 6)/2, n20_dia/2 + 4])
                        rotate([0, 90, 0])
                            cylinder(d=n20_dia + 0.4, h=n20_len + 0.5);
                    // Clamp slit
                    translate([2, (n20_dia + 6)/2 - 0.5, n20_dia/2 + 2])
                        cube([n20_len + 0.5, 1, 5]);
                }
            }

            // L9110S platform (behind motor)
            translate([n20_len + 10, 2, insert_floor])
                cube([2, drive_w - 4, l9110s_h + 2]);

            // M3 bosses (2x)
            translate([3, 3, 0]) m3_boss(drive_h);
            translate([drive_l - 3, drive_w - 3, 0]) m3_boss(drive_h);
        }

        // M3 holes + nut traps
        for (pos = [[3, 3], [drive_l - 3, drive_w - 3]]) {
            translate([pos[0], pos[1], -0.5])
                cylinder(d=m3_hole, h=drive_h + 1);
            translate([pos[0], pos[1], 0])
                m3_nut_pocket();
        }

        // Motor shaft exit hole
        translate([4, drive_w/2 + (n20_dia + 6)/2, insert_floor + n20_dia/2 + 4])
            rotate([0, -90, 0])
                cylinder(d=4, h=6);
    }
}

module drivetrain_ghosts() {
    // N20 motor (green cylinder)
    color("OliveDrab", 0.5)
        translate([7, drive_w/2 + (n20_dia + 6)/2, insert_floor + n20_dia/2 + 4])
            rotate([0, 90, 0])
                cylinder(d=n20_dia, h=n20_len);

    // L9110S (red)
    color("Crimson", 0.5)
        translate([n20_len + 10, 4, insert_floor + 2])
            cube([l9110s_l, l9110s_w, l9110s_h]);
}

// =====================================================================
// SENSOR INSERT (IMU + slip ring mount)
// Holds: MPU-6050 IMU, centered in hull
// Secured via 2x M2 screws (uses M3 boss for simplicity here)
// =====================================================================

module sensor_insert() {
    s_l = 35;
    s_w = 30;
    color("SlateGray", 0.8)
    difference() {
        union() {
            cube([s_l, s_w, insert_floor]);
            // IMU cradle walls
            translate([5, 3, insert_floor])
                difference() {
                    cube([mpu_l + 4, mpu_w + 4, mpu_h + 3]);
                    translate([2, 2, -0.5])
                        cube([mpu_l + 0.5, mpu_w + 0.5, mpu_h + 4]);
                }
            // M3 bosses
            translate([3, 3, 0]) m3_boss(8);
            translate([s_l - 3, s_w - 3, 0]) m3_boss(8);
        }
        for (pos = [[3, 3], [s_l - 3, s_w - 3]]) {
            translate([pos[0], pos[1], -0.5])
                cylinder(d=m3_hole, h=10);
            translate([pos[0], pos[1], 0])
                m3_nut_pocket();
        }
    }
}

// =====================================================================
// ASSEMBLY VIEW
// =====================================================================

module inserts_assembly() {
    // Power hub (center of hull)
    translate([20, 70, 0])
        power_hub_insert();
    translate([20, 70, 0])
        power_hub_ghosts();

    // Left drivetrain
    translate([130, 5, 0])
        drivetrain_insert();
    translate([130, 5, 0])
        drivetrain_ghosts();

    // Right drivetrain
    translate([130, 160, 0])
        drivetrain_insert();
    translate([130, 160, 0])
        drivetrain_ghosts();

    // Sensor insert (center)
    translate([55, 85, 0])
        sensor_insert();
}

// =====================================================================
// PART SELECTOR
// =====================================================================

if (part == "power_hub") {
    power_hub_insert();
    power_hub_ghosts();
} else if (part == "drivetrain") {
    drivetrain_insert();
    drivetrain_ghosts();
} else if (part == "sensor") {
    sensor_insert();
} else if (part == "assembly") {
    inserts_assembly();
}
