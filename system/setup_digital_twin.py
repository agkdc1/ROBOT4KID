"""Set up robot_spec.json for existing tank and train projects.

Matches part IDs to actual rendered STL files and provides correct
assembly positions for the 3D viewer.
"""

import json
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
JOBS_DIR = PROJECT_ROOT / "simulation_server" / "jobs"

PRINTER = {
    "name": "Bambu Lab A1 Mini",
    "build_volume_mm": [180, 180, 180],
    "nozzle_diameter_mm": 0.4,
    "layer_height_mm": 0.2,
    "material": "PLA",
    "wall_thickness_mm": 1.2,
    "tolerance_mm": 0.2,
}

TANK_SPEC = {
    "name": "M1A1 Abrams",
    "version": "1.0.0",
    "description": "1/10 scale M1A1 Abrams tank with dual ESP32-CAM, turret, FCS",
    "model_type": "tank",
    "printer": PRINTER,
    "parts": [
        {"id": "hull", "name": "Hull Chassis", "scad_file": "chassis/hull.scad",
         "category": "chassis", "dimensions_mm": [300, 99, 88],
         "mass_grams": 175, "color": "#5a6e3a"},
        {"id": "track_assembly", "name": "Track Assembly",
         "scad_file": "chassis/track_assembly.scad",
         "category": "chassis", "dimensions_mm": [153, 160, 30],
         "mass_grams": 90, "color": "#333333"},
        {"id": "electronics_bay", "name": "Electronics Bay",
         "scad_file": "chassis/electronics_bay.scad",
         "category": "chassis", "dimensions_mm": [138, 86, 74],
         "mass_grams": 30, "color": "#444444"},
        {"id": "turret_body", "name": "Turret Body",
         "scad_file": "turret/turret_body.scad",
         "category": "turret", "dimensions_mm": [120, 95, 50],
         "mass_grams": 65, "color": "#4a5e2a"},
        {"id": "gun_barrel", "name": "Gun Barrel",
         "scad_file": "turret/gun_barrel.scad",
         "category": "turret", "dimensions_mm": [16, 16, 138],
         "mass_grams": 12, "color": "#3a4e1a"},
        {"id": "console_cradle", "name": "Console Cradle",
         "scad_file": "cockpit/console_cradle.scad",
         "category": "console", "dimensions_mm": [9, 9, 80],
         "mass_grams": 40, "color": "#2a2a2a"},
    ],
    "joints": [
        # Tracks alongside hull
        {"name": "track_mount", "type": "fixed",
         "parent_part": "hull", "child_part": "track_assembly",
         "axis": [1, 0, 0], "origin_xyz": [75, -35, 0],
         "origin_rpy": [0, 0, 0], "fastener": "m4_screw"},
        # Electronics bay inside hull rear
        {"name": "ebay_mount", "type": "fixed",
         "parent_part": "hull", "child_part": "electronics_bay",
         "axis": [1, 0, 0], "origin_xyz": [160, 5, 5],
         "origin_rpy": [0, 0, 0], "fastener": "m3_screw"},
        # Turret on top of hull
        {"name": "turret_rotation", "type": "revolute",
         "parent_part": "hull", "child_part": "turret_body",
         "axis": [0, 0, 1], "origin_xyz": [165, 0, 88],
         "origin_rpy": [0, 0, 0],
         "limits": {"lower": -3.14, "upper": 3.14, "effort": 5, "velocity": 1},
         "fastener": "press_fit"},
        # Gun barrel from turret front
        {"name": "barrel_elevation", "type": "revolute",
         "parent_part": "turret_body", "child_part": "gun_barrel",
         "axis": [0, 1, 0], "origin_xyz": [120, 47, 30],
         "origin_rpy": [0, 0, 0],
         "limits": {"lower": -0.17, "upper": 0.35, "effort": 2, "velocity": 0.5},
         "fastener": "m4_screw"},
        # Console separate
        {"name": "console_offset", "type": "fixed",
         "parent_part": "hull", "child_part": "console_cradle",
         "axis": [1, 0, 0], "origin_xyz": [400, 0, 0],
         "origin_rpy": [0, 0, 0], "fastener": "snap_fit"},
    ],
    "electronics": [
        {"id": "hull_esp32cam", "type": "ESP32-CAM", "host_part": "hull",
         "mount_position_mm": [10, 35, 50], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "turret_esp32cam", "type": "ESP32-CAM", "host_part": "turret_body",
         "mount_position_mm": [100, 35, 25], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "hull_motor_driver", "type": "L298N", "host_part": "electronics_bay",
         "mount_position_mm": [10, 20, 5], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "hull_gyro", "type": "MPU6050", "host_part": "electronics_bay",
         "mount_position_mm": [60, 40, 5], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "turret_tof_sensor", "type": "VL53L1X", "host_part": "turret_body",
         "mount_position_mm": [105, 35, 15], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "turret_rotation_motor", "type": "N20-Motor", "host_part": "hull",
         "mount_position_mm": [165, 45, 75], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "turret_elevation_servo", "type": "N20-Motor", "host_part": "turret_body",
         "mount_position_mm": [110, 47, 20], "mount_orientation_rpy": [0, 0, 0]},
    ],
    "firmware_config": {"wifi_ssid": "TANK_CTRL", "wifi_password": "tank1234"},
    "metadata": {"scale": "1:10", "real_vehicle": "M1A1 Abrams"},
}

TRAIN_SPEC = {
    "name": "Shinkansen N700",
    "version": "1.0.0",
    "description": "Plarail-compatible Shinkansen N700 train",
    "model_type": "train",
    "printer": PRINTER,
    "parts": [
        {"id": "locomotive", "name": "Locomotive Body",
         "scad_file": "train/locomotive.scad",
         "category": "chassis", "dimensions_mm": [130, 36, 35],
         "mass_grams": 35, "color": "#e0e0e0"},
        {"id": "motor_mount", "name": "Motor Mount",
         "scad_file": "train/motor_mount.scad",
         "category": "chassis", "dimensions_mm": [33, 35, 8],
         "mass_grams": 5, "color": "#555555"},
        {"id": "battery_bay", "name": "Battery Bay",
         "scad_file": "train/battery_bay.scad",
         "category": "chassis", "dimensions_mm": [15, 8, 5],
         "mass_grams": 3, "color": "#444444"},
        {"id": "camera_mount", "name": "Camera Mount",
         "scad_file": "train/camera_mount.scad",
         "category": "chassis", "dimensions_mm": [1, 1, 1],
         "mass_grams": 1, "color": "#333333"},
        {"id": "train_console", "name": "Train Console",
         "scad_file": "cockpit/train_console.scad",
         "category": "console", "dimensions_mm": [220, 140, 78],
         "mass_grams": 120, "color": "#1a1a2e"},
    ],
    "joints": [
        {"name": "motor_to_loco", "type": "fixed",
         "parent_part": "locomotive", "child_part": "motor_mount",
         "axis": [1, 0, 0], "origin_xyz": [90, 0, 0],
         "origin_rpy": [0, 0, 0], "fastener": "snap_fit"},
        {"name": "battery_to_loco", "type": "fixed",
         "parent_part": "locomotive", "child_part": "battery_bay",
         "axis": [1, 0, 0], "origin_xyz": [40, 14, 2],
         "origin_rpy": [0, 0, 0], "fastener": "snap_fit"},
        {"name": "camera_to_loco", "type": "fixed",
         "parent_part": "locomotive", "child_part": "camera_mount",
         "axis": [1, 0, 0], "origin_xyz": [2, 5, 10],
         "origin_rpy": [0, 0, 0], "fastener": "snap_fit"},
        {"name": "console_offset", "type": "fixed",
         "parent_part": "locomotive", "child_part": "train_console",
         "axis": [1, 0, 0], "origin_xyz": [200, 0, 0],
         "origin_rpy": [0, 0, 0], "fastener": "snap_fit"},
    ],
    "electronics": [
        {"id": "train_esp32cam", "type": "ESP32-CAM", "host_part": "camera_mount",
         "mount_position_mm": [0, 0, 0], "mount_orientation_rpy": [0, -0.174, 0]},
        {"id": "train_drv8833", "type": "DRV8833", "host_part": "motor_mount",
         "mount_position_mm": [5, 8, 4], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "train_battery", "type": "Battery-1S", "host_part": "battery_bay",
         "mount_position_mm": [0, 0, 0], "mount_orientation_rpy": [0, 0, 0]},
        {"id": "train_motor", "type": "N20-Motor", "host_part": "motor_mount",
         "mount_position_mm": [15, 17, 0], "mount_orientation_rpy": [0, 0, 0]},
    ],
    "firmware_config": {"wifi_ssid": "TRAIN_CTRL", "wifi_password": "train1234"},
    "metadata": {"scale": "1:1", "real_vehicle": "Shinkansen N700"},
}


def main():
    for proj_id, spec in [(15, TANK_SPEC), (16, TRAIN_SPEC)]:
        job_id_path = PROJECT_ROOT / f"planning_server/data/projects/{proj_id}/simulation_job_id.txt"
        job_id = job_id_path.read_text(encoding="utf-8").strip()
        job_dir = JOBS_DIR / job_id
        out = job_dir / "robot_spec.json"
        out.write_text(json.dumps(spec, indent=2), encoding="utf-8")
        print(f"Project {proj_id} ({spec['name']}): {len(spec['parts'])} parts, "
              f"{len(spec['electronics'])} electronics -> {out}")


if __name__ == "__main__":
    main()
