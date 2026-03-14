// M1A1 Abrams — Gun Barrel
// Quick-change bayonet mount design

use <../libs/common.scad>
use <../libs/m4_hardware.scad>

// --- Barrel Parameters ---
barrel_length = 120;
barrel_od = 12;               // Outer diameter
barrel_id = 8;                // Inner bore (for projectile)
barrel_wall = (barrel_od - barrel_id) / 2;

// Bayonet mount
bayonet_od = 13.5;            // Must fit in turret bore (14mm)
bayonet_length = 8;
bayonet_lug_width = 3;
bayonet_lug_depth = 1.5;

// Muzzle brake
muzzle_od = 16;
muzzle_length = 10;

$fn = 64;

module bayonet_mount() {
    // Male bayonet — quarter-turn lock into turret trunnion
    difference() {
        union() {
            // Base cylinder
            cylinder(h=bayonet_length, d=bayonet_od);
            // Locking lugs (2 opposing)
            for (a = [0, 180])
                rotate([0, 0, a])
                    translate([bayonet_od/2 - 0.5, -bayonet_lug_width/2, bayonet_length - bayonet_lug_depth])
                        cube([bayonet_lug_depth + 0.5, bayonet_lug_width, bayonet_lug_depth]);
        }
        // Bore
        translate([0, 0, -0.05])
            cylinder(h=bayonet_length + 0.1, d=barrel_id);
    }
}

module barrel_tube() {
    difference() {
        cylinder(h=barrel_length, d=barrel_od);
        translate([0, 0, -0.05])
            cylinder(h=barrel_length + 0.1, d=barrel_id);
    }
}

module muzzle_brake() {
    difference() {
        cylinder(h=muzzle_length, d=muzzle_od);
        translate([0, 0, -0.05])
            cylinder(h=muzzle_length + 0.1, d=barrel_id);
        // Muzzle brake slots
        for (a = [0:60:359])
            rotate([0, 0, a])
                translate([barrel_od/2 + 0.5, -1, 2])
                    cube([3, 2, muzzle_length - 4]);
    }
}

module gun_barrel() {
    // Bayonet mount at base
    bayonet_mount();

    // Main barrel tube
    translate([0, 0, bayonet_length])
        barrel_tube();

    // Muzzle brake at tip
    translate([0, 0, bayonet_length + barrel_length])
        muzzle_brake();
}

gun_barrel();
