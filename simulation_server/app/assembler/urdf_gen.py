"""URDF generator — assembles STL parts with joints into a URDF file."""

import logging
import math
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

from shared.schemas.robot_spec import RobotSpec, JointType
from shared.electronics_catalog import lookup as elec_lookup

logger = logging.getLogger(__name__)

# Default density for PLA in g/mm^3
PLA_DENSITY = 0.00124


def _inertia_box(mass: float, x: float, y: float, z: float) -> dict:
    """Compute inertia tensor for a box (approximation)."""
    return {
        "ixx": mass / 12.0 * (y * y + z * z),
        "iyy": mass / 12.0 * (x * x + z * z),
        "izz": mass / 12.0 * (x * x + y * y),
        "ixy": 0.0,
        "ixz": 0.0,
        "iyz": 0.0,
    }


def generate_urdf(
    robot_spec: RobotSpec,
    stl_dir: Path,
    output_path: Path,
) -> str:
    """Generate a URDF file from a RobotSpec.

    Args:
        robot_spec: The robot specification.
        stl_dir: Directory containing rendered STL files.
        output_path: Where to write the URDF file.

    Returns:
        Path to the generated URDF file.
    """
    robot = Element("robot", name=robot_spec.name.replace(" ", "_"))

    # Track which parts have been added as links
    parts_by_id = {p.id: p for p in robot_spec.parts}

    # Create links for each part
    for part in robot_spec.parts:
        link = SubElement(robot, "link", name=part.id)

        # Visual geometry
        visual = SubElement(link, "visual")
        vis_origin = SubElement(visual, "origin", xyz="0 0 0", rpy="0 0 0")
        vis_geom = SubElement(visual, "geometry")
        stl_file = stl_dir / f"{part.id}.stl"
        # Use relative path for portability
        stl_rel = stl_file.name if stl_file.exists() else f"{part.id}.stl"
        SubElement(vis_geom, "mesh", filename=stl_rel)

        vis_material = SubElement(visual, "material", name=f"mat_{part.id}")
        # Convert hex color to RGBA
        color_hex = part.color.lstrip("#")
        if len(color_hex) == 3:
            color_hex = "".join(c * 2 for c in color_hex)
        r = int(color_hex[0:2], 16) / 255.0
        g = int(color_hex[2:4], 16) / 255.0
        b = int(color_hex[4:6], 16) / 255.0
        SubElement(vis_material, "color", rgba=f"{r:.3f} {g:.3f} {b:.3f} 1.0")

        # Collision geometry (same mesh)
        collision = SubElement(link, "collision")
        col_origin = SubElement(collision, "origin", xyz="0 0 0", rpy="0 0 0")
        col_geom = SubElement(collision, "geometry")
        SubElement(col_geom, "mesh", filename=stl_rel)

        # Inertial properties
        inertial = SubElement(link, "inertial")
        mass_kg = part.mass_grams / 1000.0 if part.mass_grams > 0 else 0.1
        SubElement(inertial, "mass", value=f"{mass_kg:.4f}")
        SubElement(inertial, "origin", xyz="0 0 0", rpy="0 0 0")

        dims = part.dimensions_mm
        # Convert mm to m for URDF
        inertia = _inertia_box(
            mass_kg,
            dims[0] / 1000.0,
            dims[1] / 1000.0,
            dims[2] / 1000.0,
        )
        SubElement(
            inertial,
            "inertia",
            ixx=f"{inertia['ixx']:.6f}",
            iyy=f"{inertia['iyy']:.6f}",
            izz=f"{inertia['izz']:.6f}",
            ixy=f"{inertia['ixy']:.6f}",
            ixz=f"{inertia['ixz']:.6f}",
            iyz=f"{inertia['iyz']:.6f}",
        )

    # Create joints
    for joint_spec in robot_spec.joints:
        joint_type_map = {
            JointType.FIXED: "fixed",
            JointType.REVOLUTE: "revolute",
            JointType.CONTINUOUS: "continuous",
            JointType.PRISMATIC: "prismatic",
        }
        joint = SubElement(
            robot,
            "joint",
            name=joint_spec.name,
            type=joint_type_map.get(joint_spec.type, "fixed"),
        )

        SubElement(joint, "parent", link=joint_spec.parent_part)
        SubElement(joint, "child", link=joint_spec.child_part)

        # Origin (convert mm to m)
        xyz = " ".join(f"{v / 1000.0:.4f}" for v in joint_spec.origin_xyz)
        rpy = " ".join(f"{v:.4f}" for v in joint_spec.origin_rpy)
        SubElement(joint, "origin", xyz=xyz, rpy=rpy)

        # Axis
        axis = " ".join(f"{v:.1f}" for v in joint_spec.axis)
        SubElement(joint, "axis", xyz=axis)

        # Limits (supports both JointLimits model and raw dict)
        if joint_spec.limits and joint_spec.type in (JointType.REVOLUTE, JointType.PRISMATIC):
            lim = joint_spec.limits
            if hasattr(lim, "lower"):
                # Pydantic JointLimits model
                SubElement(
                    joint, "limit",
                    lower=str(lim.lower), upper=str(lim.upper),
                    effort=str(lim.effort), velocity=str(lim.velocity),
                )
            else:
                # Raw dict (backwards compat)
                SubElement(
                    joint, "limit",
                    lower=str(lim.get("lower", -math.pi)),
                    upper=str(lim.get("upper", math.pi)),
                    effort=str(lim.get("effort", 10.0)),
                    velocity=str(lim.get("velocity", 1.0)),
                )

    # Create links and fixed joints for electronic components
    for elec in robot_spec.electronics:
        info = elec_lookup(elec.type)
        elec_link_name = f"elec_{elec.id}"

        link = SubElement(robot, "link", name=elec_link_name)

        # Visual geometry — use rendered STL if available, else box
        visual = SubElement(link, "visual")
        SubElement(visual, "origin", xyz="0 0 0", rpy="0 0 0")
        vis_geom = SubElement(visual, "geometry")
        stl_file = stl_dir / f"{elec_link_name}.stl"
        if stl_file.exists():
            SubElement(vis_geom, "mesh", filename=stl_file.name)
        elif info:
            dims_m = tuple(d / 1000.0 for d in info.dimensions_mm)
            SubElement(vis_geom, "box", size=f"{dims_m[0]:.4f} {dims_m[1]:.4f} {dims_m[2]:.4f}")
        else:
            SubElement(vis_geom, "box", size="0.02 0.02 0.01")

        vis_mat = SubElement(visual, "material", name=f"mat_{elec_link_name}")
        if info:
            ch = info.color_hex.lstrip("#")
            r, g, b = int(ch[0:2], 16) / 255.0, int(ch[2:4], 16) / 255.0, int(ch[4:6], 16) / 255.0
        else:
            r, g, b = 0.2, 0.6, 0.2
        SubElement(vis_mat, "color", rgba=f"{r:.3f} {g:.3f} {b:.3f} 0.85")

        # Collision — simplified box
        collision = SubElement(link, "collision")
        SubElement(collision, "origin", xyz="0 0 0", rpy="0 0 0")
        col_geom = SubElement(collision, "geometry")
        if info:
            dims_m = tuple(d / 1000.0 for d in info.dimensions_mm)
            SubElement(col_geom, "box", size=f"{dims_m[0]:.4f} {dims_m[1]:.4f} {dims_m[2]:.4f}")
        else:
            SubElement(col_geom, "box", size="0.02 0.02 0.01")

        # Inertial
        inertial = SubElement(link, "inertial")
        mass_kg = (info.mass_grams / 1000.0) if info else 0.01
        SubElement(inertial, "mass", value=f"{mass_kg:.4f}")
        SubElement(inertial, "origin", xyz="0 0 0", rpy="0 0 0")
        if info:
            dims_m = tuple(d / 1000.0 for d in info.dimensions_mm)
        else:
            dims_m = (0.02, 0.02, 0.01)
        inertia = _inertia_box(mass_kg, *dims_m)
        SubElement(
            inertial, "inertia",
            ixx=f"{inertia['ixx']:.6f}", iyy=f"{inertia['iyy']:.6f}",
            izz=f"{inertia['izz']:.6f}", ixy="0", ixz="0", iyz="0",
        )

        # Fixed joint from host part to electronic component
        if elec.host_part in parts_by_id:
            joint = SubElement(robot, "joint", name=f"mount_{elec.id}", type="fixed")
            SubElement(joint, "parent", link=elec.host_part)
            SubElement(joint, "child", link=elec_link_name)
            xyz = " ".join(f"{v / 1000.0:.4f}" for v in elec.mount_position_mm)
            rpy = " ".join(f"{v:.4f}" for v in elec.mount_orientation_rpy)
            SubElement(joint, "origin", xyz=xyz, rpy=rpy)
            SubElement(joint, "axis", xyz="0 0 1")

    # Pretty print
    rough_string = tostring(robot, encoding="unicode")
    dom = minidom.parseString(rough_string)
    urdf_xml = dom.toprettyxml(indent="  ")

    # Remove extra XML declaration
    lines = urdf_xml.split("\n")
    if lines and lines[0].startswith("<?xml"):
        lines = lines[1:]
    urdf_xml = '<?xml version="1.0"?>\n' + "\n".join(lines)

    output_path.write_text(urdf_xml)
    logger.info(f"Generated URDF: {output_path}")
    return str(output_path)
