// M1A1 Abrams — Gun Barrel (1:26 scale)
// Quick-change bayonet mount design
// Bore evacuator is a defining visual feature of the M256 gun

use <../libs/common.scad>
use <../libs/m4_hardware.scad>

// --- Barrel Parameters ---
barrel_length = 162;              // Total with bayonet(8)+muzzle(10) = 180mm = fits build vol
barrel_od = 12;               // Outer diameter
barrel_id = 8;                // Inner bore (for projectile)
barrel_wall = (barrel_od - barrel_id) / 2;

// Bayonet mount
bayonet_od = 13.5;            // Must fit in turret bore (14mm)
bayonet_length = 8;
bayonet_lug_width = 3;
bayonet_lug_depth = 1.5;

// Bore evacuator — cylindrical bulge ~40% from muzzle end
bore_evac_od = 20;
bore_evac_length = 15;
bore_evac_pos = barrel_length * 0.6;  // 60% from breech = 40% from muzzle

// Muzzle brake
muzzle_od = 14;
muzzle_length = 10;

// Thermal sleeve — covers barrel between bayonet and bore evacuator
thermal_sleeve_od = 13;        // Slightly larger than barrel_od (12mm)
thermal_sleeve_start = 2;      // Start just past bayonet (offset from barrel_tube base)
thermal_sleeve_end_margin = 3; // End just before bore evacuator

// Muzzle Reference Sensor (MRS) — tiny reflector on muzzle tip
mrs_dia = 2;
mrs_length = 1.5;
mrs_offset = muzzle_od / 2;   // Offset from bore center (on muzzle OD surface)

// Bore evacuator taper transition
bore_evac_taper = 3;           // 3mm cone transition on each end

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
        union() {
            // Main barrel tube
            cylinder(h=barrel_length, d=barrel_od);
            // Bore evacuator bulge
            translate([0, 0, bore_evac_pos - bore_evac_length/2])
                bore_evacuator();
        }
        translate([0, 0, -0.05])
            cylinder(h=barrel_length + 0.1, d=barrel_id);
    }
}

module bore_evacuator() {
    // Cylindrical bulge with cone transitions (not sharp steps)
    // Rear taper: barrel_od -> bore_evac_od over bore_evac_taper mm
    cylinder(h=bore_evac_taper, d1=barrel_od, d2=bore_evac_od);
    // Main evacuator body
    translate([0, 0, bore_evac_taper])
        cylinder(h=bore_evac_length - 2 * bore_evac_taper, d=bore_evac_od);
    // Front taper: bore_evac_od -> barrel_od over bore_evac_taper mm
    translate([0, 0, bore_evac_length - bore_evac_taper])
        cylinder(h=bore_evac_taper, d1=bore_evac_od, d2=barrel_od);
}

module thermal_sleeve() {
    // Thin tube wrapping barrel from just past bayonet to just before bore evacuator
    sleeve_length = (bore_evac_pos - bore_evac_length/2) - thermal_sleeve_start - thermal_sleeve_end_margin;
    translate([0, 0, thermal_sleeve_start])
        difference() {
            cylinder(h=sleeve_length, d=thermal_sleeve_od);
            translate([0, 0, -0.05])
                cylinder(h=sleeve_length + 0.1, d=barrel_od + 0.01);
        }
}

module muzzle_reference_sensor() {
    // MRS reflector — tiny cylinder on muzzle tip, offset 90 degrees from bore
    translate([mrs_offset, 0, 0])
        cylinder(h=mrs_length, d=mrs_dia);
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

    // Main barrel tube (includes bore evacuator)
    translate([0, 0, bayonet_length])
        barrel_tube();

    // Thermal sleeve on barrel (between bayonet and bore evacuator)
    translate([0, 0, bayonet_length])
        thermal_sleeve();

    // Muzzle brake at tip
    translate([0, 0, bayonet_length + barrel_length])
        muzzle_brake();

    // Muzzle Reference Sensor (MRS) at very tip of muzzle
    translate([0, 0, bayonet_length + barrel_length + muzzle_length])
        muzzle_reference_sensor();
}

gun_barrel();
