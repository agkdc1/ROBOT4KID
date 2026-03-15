"""Electronics component catalog — maps component types to physical properties.

Single source of truth for component dimensions, mass, OpenSCAD module names,
and Webots sensor types. Data derived from config/hardware_specs.yaml and
cad/libs/electronics.scad.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class ComponentInfo:
    """Physical and rendering properties of an electronic component."""
    scad_module: str          # OpenSCAD dummy module name (without parens)
    dimensions_mm: tuple[float, float, float]  # L x W x H
    mass_grams: float         # Estimated mass
    category: str             # pcb, motor, battery, sensor, connector, peripheral
    color_hex: str            # Viewer color
    webots_device: str | None = None  # Webots device type if applicable


# Maps ElectronicComponent.type -> physical info
CATALOG: dict[str, ComponentInfo] = {
    # --- Microcontrollers ---
    "ESP32-DevKitC": ComponentInfo(
        scad_module="esp32_dummy",
        dimensions_mm=(55, 28, 13),
        mass_grams=10,
        category="pcb",
        color_hex="#1565c0",
    ),
    "Terminal-Shield": ComponentInfo(
        scad_module="terminal_shield_dummy",
        dimensions_mm=(85, 65, 20),
        mass_grams=30,
        category="pcb",
        color_hex="#2e7d32",
    ),
    "ESP32-CAM": ComponentInfo(
        scad_module="esp32cam_dummy",
        dimensions_mm=(40, 27, 12),
        mass_grams=10,
        category="pcb",
        color_hex="#0d47a1",
        webots_device="Camera",
    ),
    # --- Motor drivers ---
    "L298N": ComponentInfo(
        scad_module="l298n_dummy",
        dimensions_mm=(43, 43, 27),
        mass_grams=25,
        category="pcb",
        color_hex="#b71c1c",
    ),
    "DRV8833": ComponentInfo(
        scad_module="drv8833_dummy",
        dimensions_mm=(17.8, 17.8, 4),
        mass_grams=3,
        category="pcb",
        color_hex="#880e4f",
    ),
    # --- Power ---
    "LM2596": ComponentInfo(
        scad_module="lm2596_dummy",
        dimensions_mm=(43, 21, 14),
        mass_grams=10,
        category="pcb",
        color_hex="#1b5e20",
    ),
    "Battery-2S": ComponentInfo(
        scad_module="battery_holder_dummy",
        dimensions_mm=(77, 41, 20),
        mass_grams=90,
        category="battery",
        color_hex="#e65100",
    ),
    "Battery-1S": ComponentInfo(
        scad_module="battery_holder_1cell_dummy",
        dimensions_mm=(77, 21, 20),
        mass_grams=50,
        category="battery",
        color_hex="#ef6c00",
    ),
    # --- Motors ---
    "N20-Motor": ComponentInfo(
        scad_module="n20_motor_dummy",
        dimensions_mm=(25, 12, 12),
        mass_grams=15,
        category="motor",
        color_hex="#757575",
    ),
    # --- Sensors ---
    "MPU6050": ComponentInfo(
        scad_module="mpu6050_dummy",
        dimensions_mm=(21, 16, 3),
        mass_grams=2,
        category="sensor",
        color_hex="#4a148c",
        webots_device="InertialUnit",
    ),
    "VL53L1X": ComponentInfo(
        scad_module="vl53l1x_dummy",
        dimensions_mm=(13, 18, 4),
        mass_grams=1,
        category="sensor",
        color_hex="#311b92",
        webots_device="DistanceSensor",
    ),
    # --- Connectors ---
    "WAGO-221": ComponentInfo(
        scad_module="wago_dummy",
        dimensions_mm=(20, 13, 16),
        mass_grams=5,
        category="connector",
        color_hex="#ff6f00",
    ),
    # --- Peripherals ---
    "MCP3008": ComponentInfo(
        scad_module="mcp3008_dummy",
        dimensions_mm=(40, 20, 8),
        mass_grams=5,
        category="pcb",
        color_hex="#006064",
    ),
    "GL-MT300N": ComponentInfo(
        scad_module="glinet_mt300n_dummy",
        dimensions_mm=(58, 58, 25),
        mass_grams=38,
        category="peripheral",
        color_hex="#ffffff",
    ),
    "Anker-10000": ComponentInfo(
        scad_module="anker_slim10000_dummy",
        dimensions_mm=(149, 68, 14),
        mass_grams=212,
        category="battery",
        color_hex="#212121",
    ),
    "Sabrent-Hub": ComponentInfo(
        scad_module="sabrent_hub_dummy",
        dimensions_mm=(85, 30, 15),
        mass_grams=30,
        category="peripheral",
        color_hex="#37474f",
    ),
    "PS2-Joystick": ComponentInfo(
        scad_module="ps2_joystick_dummy",
        dimensions_mm=(40, 40, 32),
        mass_grams=15,
        category="peripheral",
        color_hex="#263238",
    ),
    "RPi4": ComponentInfo(
        scad_module="rpi4_dummy",
        dimensions_mm=(85, 56, 17),
        mass_grams=46,
        category="pcb",
        color_hex="#2e7d32",
    ),
    "RPi-Display-7": ComponentInfo(
        scad_module="rpi_display_7in_dummy",
        dimensions_mm=(194, 110, 20),
        mass_grams=270,
        category="peripheral",
        color_hex="#000000",
    ),
}

# Aliases for fuzzy matching from reference spec types
_ALIASES: dict[str, str] = {
    "L9110": "L298N",
    "VL53L0X": "VL53L1X",
    "N20 Gear Motor": "N20-Motor",
    "SG90 Servo": "N20-Motor",  # approximate
}


def lookup(component_type: str) -> ComponentInfo | None:
    """Look up component info by type string, with alias support."""
    if component_type in CATALOG:
        return CATALOG[component_type]
    alias = _ALIASES.get(component_type)
    if alias:
        return CATALOG.get(alias)
    return None
