"""URDF-to-Webots PROTO converter.

Converts a URDF robot description (with optional STL meshes) into a Webots
.proto file that can be dropped into a world. Uses the ``urdf2webots``
package when available; otherwise falls back to a manual XML-based
conversion that handles the most common joint/link topologies.

Function signature:
    convert_urdf_to_proto(urdf_path, stl_dir, output_path) -> Path
"""

from __future__ import annotations

import logging
import math
import os
import re
import shutil
from pathlib import Path
from typing import Optional
from xml.etree import ElementTree as ET

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def convert_urdf_to_proto(
    urdf_path: Path | str,
    stl_dir: Path | str,
    output_path: Path | str,
) -> Path:
    """Convert a URDF file to a Webots .proto file.

    Args:
        urdf_path: Path to the input URDF file.
        stl_dir: Directory containing STL meshes referenced by the URDF.
        output_path: Where to write the generated .proto file.

    Returns:
        The resolved output path.

    Raises:
        FileNotFoundError: If the URDF file does not exist.
    """
    urdf_path = Path(urdf_path).resolve()
    stl_dir = Path(stl_dir).resolve()
    output_path = Path(output_path).resolve()

    if not urdf_path.exists():
        raise FileNotFoundError(f"URDF file not found: {urdf_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Try urdf2webots first
    try:
        return _convert_with_urdf2webots(urdf_path, stl_dir, output_path)
    except ImportError:
        logger.info("urdf2webots not installed — using manual converter")
    except Exception as exc:
        logger.warning("urdf2webots failed (%s) — falling back to manual converter", exc)

    return _convert_manual(urdf_path, stl_dir, output_path)


# ---------------------------------------------------------------------------
# urdf2webots wrapper
# ---------------------------------------------------------------------------

def _convert_with_urdf2webots(
    urdf_path: Path,
    stl_dir: Path,
    output_path: Path,
) -> Path:
    """Use the urdf2webots package for conversion."""
    from urdf2webots.importer import convertUrdfFile  # type: ignore[import-untyped]

    convertUrdfFile(
        input=str(urdf_path),
        output=str(output_path),
        robotName=None,  # auto from URDF
        normal=True,
        boxCollision=False,
        initTranslation="0 0 0.05",
        initRotation="0 0 1 0",
    )

    logger.info("PROTO generated via urdf2webots: %s", output_path)
    return output_path


# ---------------------------------------------------------------------------
# Manual converter
# ---------------------------------------------------------------------------

def _convert_manual(
    urdf_path: Path,
    stl_dir: Path,
    output_path: Path,
) -> Path:
    """Manual URDF → PROTO conversion for common tank-robot topologies."""
    tree = ET.parse(urdf_path)
    root = tree.getroot()
    robot_name = root.get("name", "Robot").replace(" ", "_")

    links: dict[str, ET.Element] = {}
    joints: list[ET.Element] = []

    for link_el in root.findall("link"):
        name = link_el.get("name", "")
        links[name] = link_el

    for joint_el in root.findall("joint"):
        joints.append(joint_el)

    # Build parent→children map
    children_map: dict[str, list[tuple[str, ET.Element]]] = {}
    child_to_parent: dict[str, str] = {}
    for j in joints:
        parent = j.find("parent")
        child = j.find("child")
        if parent is None or child is None:
            continue
        pname = parent.get("link", "")
        cname = child.get("link", "")
        children_map.setdefault(pname, []).append((cname, j))
        child_to_parent[cname] = pname

    # Find root link (no parent)
    root_links = [n for n in links if n not in child_to_parent]
    root_link = root_links[0] if root_links else (list(links.keys())[0] if links else "base")

    lines: list[str] = []
    lines.append(f'#VRML_SIM R2023b utf8')
    lines.append(f'# Generated from {urdf_path.name}')
    lines.append(f'')
    lines.append(f'PROTO {robot_name} [')
    lines.append(f'  field SFVec3f    translation  0 0 0.05')
    lines.append(f'  field SFRotation rotation     0 0 1 0')
    lines.append(f'  field SFString   name         "{robot_name}"')
    lines.append(f'  field SFString   controller   "tank_controller"')
    lines.append(f']')
    lines.append(f'{{')
    lines.append(f'  Robot {{')
    lines.append(f'    translation IS translation')
    lines.append(f'    rotation IS rotation')
    lines.append(f'    name IS name')
    lines.append(f'    controller IS controller')
    lines.append(f'    supervisor TRUE')
    lines.append(f'    children [')

    _emit_link(lines, root_link, links, children_map, stl_dir, indent=6)

    # Add standard devices at the robot level
    lines.append(f'      InertialUnit {{')
    lines.append(f'        name "imu"')
    lines.append(f'      }}')
    lines.append(f'      Accelerometer {{')
    lines.append(f'        name "accelerometer"')
    lines.append(f'      }}')
    lines.append(f'      Gyro {{')
    lines.append(f'        name "gyro"')
    lines.append(f'      }}')

    lines.append(f'    ]')

    # Bounding object from root link
    bbox = _get_link_bbox(links.get(root_link))
    lines.append(f'    boundingObject Box {{')
    lines.append(f'      size {bbox[0]} {bbox[1]} {bbox[2]}')
    lines.append(f'    }}')

    mass = _get_link_mass(links.get(root_link))
    lines.append(f'    physics Physics {{')
    lines.append(f'      density -1')
    lines.append(f'      mass {mass}')
    lines.append(f'    }}')

    lines.append(f'  }}')
    lines.append(f'}}')

    output_path.write_text("\n".join(lines), encoding="utf-8")
    logger.info("PROTO generated (manual): %s", output_path)
    return output_path


def _emit_link(
    lines: list[str],
    link_name: str,
    links: dict[str, ET.Element],
    children_map: dict[str, list[tuple[str, ET.Element]]],
    stl_dir: Path,
    indent: int,
) -> None:
    """Recursively emit a link and its child joints."""
    pad = " " * indent
    link_el = links.get(link_name)

    # Emit visual geometry
    lines.append(f'{pad}Solid {{')
    lines.append(f'{pad}  name "{link_name}"')
    lines.append(f'{pad}  children [')

    # Shape
    stl_file = stl_dir / f"{link_name}.stl"
    if stl_file.exists():
        lines.append(f'{pad}    Shape {{')
        lines.append(f'{pad}      appearance PBRAppearance {{')
        color = _get_link_color(link_el)
        lines.append(f'{pad}        baseColor {color[0]} {color[1]} {color[2]}')
        lines.append(f'{pad}        roughness 0.7')
        lines.append(f'{pad}        metalness 0.2')
        lines.append(f'{pad}      }}')
        lines.append(f'{pad}      geometry Mesh {{')
        lines.append(f'{pad}        url ["{stl_file.as_posix()}"]')
        lines.append(f'{pad}      }}')
        lines.append(f'{pad}    }}')
    else:
        # Fallback box
        bbox = _get_link_bbox(link_el)
        lines.append(f'{pad}    Shape {{')
        lines.append(f'{pad}      appearance PBRAppearance {{')
        color = _get_link_color(link_el)
        lines.append(f'{pad}        baseColor {color[0]} {color[1]} {color[2]}')
        lines.append(f'{pad}        roughness 0.7')
        lines.append(f'{pad}      }}')
        lines.append(f'{pad}      geometry Box {{')
        lines.append(f'{pad}        size {bbox[0]} {bbox[1]} {bbox[2]}')
        lines.append(f'{pad}      }}')
        lines.append(f'{pad}    }}')

    # Child joints
    for child_name, joint_el in children_map.get(link_name, []):
        _emit_joint(lines, joint_el, child_name, links, children_map, stl_dir, indent + 4)

    # Add Webots devices based on link name heuristics
    name_lower = link_name.lower()

    # Camera devices (ESP32-CAM links)
    if "cam" in name_lower or "camera" in name_lower:
        cam_name = "turret_cam" if "turret" in name_lower else "hull_cam"
        lines.append(f'{pad}    Camera {{')
        lines.append(f'{pad}      name "{cam_name}"')
        lines.append(f'{pad}      width 320')
        lines.append(f'{pad}      height 240')
        lines.append(f'{pad}      recognition Recognition {{}}')
        lines.append(f'{pad}    }}')

    # ToF / distance sensor
    if "tof" in name_lower or "vl53" in name_lower:
        lines.append(f'{pad}    DistanceSensor {{')
        lines.append(f'{pad}      name "tof_sensor"')
        lines.append(f'{pad}      type "infra-red"')
        lines.append(f'{pad}      maxRange 4.0')
        lines.append(f'{pad}    }}')

    # IMU (MPU6050)
    if "imu" in name_lower or "mpu" in name_lower or "gyro" in name_lower:
        lines.append(f'{pad}    InertialUnit {{')
        lines.append(f'{pad}      name "{link_name}_imu"')
        lines.append(f'{pad}    }}')
        lines.append(f'{pad}    Accelerometer {{')
        lines.append(f'{pad}      name "{link_name}_accel"')
        lines.append(f'{pad}    }}')
        lines.append(f'{pad}    Gyro {{')
        lines.append(f'{pad}      name "{link_name}_gyro"')
        lines.append(f'{pad}    }}')

    lines.append(f'{pad}  ]')

    # Bounding object
    bbox = _get_link_bbox(link_el)
    lines.append(f'{pad}  boundingObject Box {{')
    lines.append(f'{pad}    size {bbox[0]} {bbox[1]} {bbox[2]}')
    lines.append(f'{pad}  }}')

    # Physics
    mass = _get_link_mass(link_el)
    lines.append(f'{pad}  physics Physics {{')
    lines.append(f'{pad}    density -1')
    lines.append(f'{pad}    mass {mass}')
    lines.append(f'{pad}  }}')

    lines.append(f'{pad}}}')


def _emit_joint(
    lines: list[str],
    joint_el: ET.Element,
    child_name: str,
    links: dict[str, ET.Element],
    children_map: dict[str, list[tuple[str, ET.Element]]],
    stl_dir: Path,
    indent: int,
) -> None:
    """Emit a URDF joint as a Webots HingeJoint with its child link."""
    pad = " " * indent
    joint_name = joint_el.get("name", "joint")
    joint_type = joint_el.get("type", "fixed")

    # Parse origin
    origin_el = joint_el.find("origin")
    xyz = "0 0 0"
    rpy = "0 0 0"
    if origin_el is not None:
        xyz = origin_el.get("xyz", "0 0 0")
        rpy = origin_el.get("rpy", "0 0 0")

    xyz_vals = [float(v) for v in xyz.split()]
    rpy_vals = [float(v) for v in rpy.split()]

    # Parse axis
    axis_el = joint_el.find("axis")
    axis = [0.0, 0.0, 1.0]
    if axis_el is not None:
        axis = [float(v) for v in axis_el.get("xyz", "0 0 1").split()]

    if joint_type == "fixed":
        # Fixed joint: just nest the child Solid with a translation
        lines.append(f'{pad}# Fixed joint: {joint_name}')
        _emit_link(lines, child_name, links, children_map, stl_dir, indent)
        return

    # Determine motor/sensor names based on joint name
    motor_name, sensor_name = _device_names_for_joint(joint_name)

    # Parse limits
    limit_el = joint_el.find("limit")
    min_pos = -math.pi
    max_pos = math.pi
    max_vel = 10.0
    max_torque = 5.0
    if limit_el is not None:
        min_pos = float(limit_el.get("lower", str(-math.pi)))
        max_pos = float(limit_el.get("upper", str(math.pi)))
        max_vel = float(limit_el.get("velocity", "10.0"))
        max_torque = float(limit_el.get("effort", "5.0"))

    lines.append(f'{pad}HingeJoint {{')
    lines.append(f'{pad}  jointParameters HingeJointParameters {{')
    lines.append(f'{pad}    axis {axis[0]} {axis[1]} {axis[2]}')
    lines.append(f'{pad}    anchor {xyz_vals[0]} {xyz_vals[1]} {xyz_vals[2]}')
    lines.append(f'{pad}  }}')
    lines.append(f'{pad}  device [')
    lines.append(f'{pad}    RotationalMotor {{')
    lines.append(f'{pad}      name "{motor_name}"')
    lines.append(f'{pad}      maxVelocity {max_vel}')
    lines.append(f'{pad}      maxTorque {max_torque}')

    if joint_type == "revolute":
        lines.append(f'{pad}      minPosition {min_pos}')
        lines.append(f'{pad}      maxPosition {max_pos}')

    lines.append(f'{pad}    }}')
    lines.append(f'{pad}    PositionSensor {{')
    lines.append(f'{pad}      name "{sensor_name}"')
    lines.append(f'{pad}    }}')
    lines.append(f'{pad}  ]')
    lines.append(f'{pad}  endPoint Solid {{')
    lines.append(f'{pad}    translation {xyz_vals[0]} {xyz_vals[1]} {xyz_vals[2]}')
    lines.append(f'{pad}    children [')

    # Recursively emit the child link content
    _emit_link_content(lines, child_name, links, children_map, stl_dir, indent + 6)

    lines.append(f'{pad}    ]')
    lines.append(f'{pad}    name "{child_name}"')

    bbox = _get_link_bbox(links.get(child_name))
    lines.append(f'{pad}    boundingObject Box {{')
    lines.append(f'{pad}      size {bbox[0]} {bbox[1]} {bbox[2]}')
    lines.append(f'{pad}    }}')

    mass = _get_link_mass(links.get(child_name))
    lines.append(f'{pad}    physics Physics {{')
    lines.append(f'{pad}      density -1')
    lines.append(f'{pad}      mass {mass}')
    lines.append(f'{pad}    }}')

    lines.append(f'{pad}  }}')
    lines.append(f'{pad}}}')


def _emit_link_content(
    lines: list[str],
    link_name: str,
    links: dict[str, ET.Element],
    children_map: dict[str, list[tuple[str, ET.Element]]],
    stl_dir: Path,
    indent: int,
) -> None:
    """Emit only the content of a link (shape + child joints) without the Solid wrapper."""
    pad = " " * indent
    link_el = links.get(link_name)

    stl_file = stl_dir / f"{link_name}.stl"
    if stl_file.exists():
        lines.append(f'{pad}Shape {{')
        lines.append(f'{pad}  appearance PBRAppearance {{')
        color = _get_link_color(link_el)
        lines.append(f'{pad}    baseColor {color[0]} {color[1]} {color[2]}')
        lines.append(f'{pad}    roughness 0.7')
        lines.append(f'{pad}    metalness 0.2')
        lines.append(f'{pad}  }}')
        lines.append(f'{pad}  geometry Mesh {{')
        lines.append(f'{pad}    url ["{stl_file.as_posix()}"]')
        lines.append(f'{pad}  }}')
        lines.append(f'{pad}}}')
    else:
        bbox = _get_link_bbox(link_el)
        lines.append(f'{pad}Shape {{')
        lines.append(f'{pad}  appearance PBRAppearance {{')
        color = _get_link_color(link_el)
        lines.append(f'{pad}    baseColor {color[0]} {color[1]} {color[2]}')
        lines.append(f'{pad}    roughness 0.7')
        lines.append(f'{pad}  }}')
        lines.append(f'{pad}  geometry Box {{')
        lines.append(f'{pad}    size {bbox[0]} {bbox[1]} {bbox[2]}')
        lines.append(f'{pad}  }}')
        lines.append(f'{pad}}}')

    # Child joints
    for child_name, joint_el in children_map.get(link_name, []):
        _emit_joint(lines, joint_el, child_name, links, children_map, stl_dir, indent)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _device_names_for_joint(joint_name: str) -> tuple[str, str]:
    """Infer motor and sensor names from a URDF joint name."""
    name_lower = joint_name.lower()

    if "left" in name_lower and ("wheel" in name_lower or "track" in name_lower or "drive" in name_lower):
        return "left_motor", "left_encoder"
    if "right" in name_lower and ("wheel" in name_lower or "track" in name_lower or "drive" in name_lower):
        return "right_motor", "right_encoder"
    if "turret" in name_lower:
        return "turret_motor", "turret_sensor"
    if "barrel" in name_lower or "elevation" in name_lower or "gun" in name_lower:
        return "barrel_motor", "barrel_sensor"

    # Generic fallback
    motor_name = joint_name + "_motor"
    sensor_name = joint_name + "_sensor"
    return motor_name, sensor_name


def _get_link_bbox(link_el: Optional[ET.Element]) -> tuple[str, str, str]:
    """Extract bounding box dimensions from a link (metres). Falls back to small box."""
    if link_el is None:
        return ("0.05", "0.05", "0.05")

    # Try collision geometry box
    for geom_parent in ("collision", "visual"):
        parent = link_el.find(geom_parent)
        if parent is None:
            continue
        box = parent.find(".//box")
        if box is not None:
            size = box.get("size", "0.05 0.05 0.05")
            parts = size.split()
            if len(parts) == 3:
                return (parts[0], parts[1], parts[2])

    # Estimate from inertia if available
    inertial = link_el.find("inertial")
    if inertial is not None:
        mass_el = inertial.find("mass")
        if mass_el is not None:
            mass = float(mass_el.get("value", "0.1"))
            # Rough cube estimate from mass (PLA ~1240 kg/m^3)
            side = (mass / 1240.0) ** (1.0 / 3.0)
            s = f"{max(0.01, side):.4f}"
            return (s, s, s)

    return ("0.05", "0.05", "0.05")


def _get_link_mass(link_el: Optional[ET.Element]) -> float:
    """Extract mass in kg from a URDF link element."""
    if link_el is None:
        return 0.1
    inertial = link_el.find("inertial")
    if inertial is None:
        return 0.1
    mass_el = inertial.find("mass")
    if mass_el is None:
        return 0.1
    return max(0.001, float(mass_el.get("value", "0.1")))


def _get_link_color(link_el: Optional[ET.Element]) -> tuple[str, str, str]:
    """Extract RGB colour from a URDF link's material. Falls back to grey."""
    if link_el is None:
        return ("0.5", "0.5", "0.5")

    visual = link_el.find("visual")
    if visual is None:
        return ("0.5", "0.5", "0.5")

    material = visual.find("material")
    if material is None:
        return ("0.5", "0.5", "0.5")

    color_el = material.find("color")
    if color_el is None:
        return ("0.5", "0.5", "0.5")

    rgba = color_el.get("rgba", "0.5 0.5 0.5 1.0")
    parts = rgba.split()
    if len(parts) >= 3:
        return (parts[0], parts[1], parts[2])
    return ("0.5", "0.5", "0.5")
