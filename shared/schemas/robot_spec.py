"""Extended URDF-based robot specification — the single source of truth.

This schema is inspired by URDF (Unified Robot Description Format) but
extended with electronics, wiring, printing constraints, and reference
proportions. It serves as the common data model across the entire pipeline:

  NL prompt → RobotSpec → OpenSCAD → STL → URDF XML → Webots PROTO

All dimensions are in millimeters (mm), masses in grams (g), angles in radians.
The URDF generator (urdf_gen.py) converts to meters/kg for the XML output.
"""

from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


# ─── Enums ───────────────────────────────────────────────────────────────────

class MaterialType(str, Enum):
    PLA = "PLA"
    PETG = "PETG"
    TPU = "TPU"
    ABS = "ABS"


class JointType(str, Enum):
    FIXED = "fixed"
    REVOLUTE = "revolute"
    CONTINUOUS = "continuous"
    PRISMATIC = "prismatic"


class ModelType(str, Enum):
    TANK = "tank"
    TRAIN = "train"
    CONSOLE = "console"


class FastenerType(str, Enum):
    M4_SCREW = "m4_screw"
    M3_SCREW = "m3_screw"
    M2_5_SCREW = "m2.5_screw"
    SNAP_FIT = "snap_fit"
    PRESS_FIT = "press_fit"
    BAYONET = "bayonet"
    MAGNETIC = "magnetic"


# ─── Physics & Inertial ─────────────────────────────────────────────────────

class InertialSpec(BaseModel):
    """URDF-compatible inertial properties for a link."""
    mass_grams: float = Field(default=0.0, description="Mass in grams")
    center_of_mass_mm: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Center of mass relative to link origin (mm)",
    )
    # Inertia tensor (computed from geometry if not specified)
    ixx: float = Field(default=0.0, description="Inertia Ixx (g*mm^2)")
    iyy: float = Field(default=0.0, description="Inertia Iyy (g*mm^2)")
    izz: float = Field(default=0.0, description="Inertia Izz (g*mm^2)")
    ixy: float = Field(default=0.0)
    ixz: float = Field(default=0.0)
    iyz: float = Field(default=0.0)


class PhysicsMaterial(BaseModel):
    """Surface physics properties for simulation."""
    friction: float = Field(default=0.5, description="Coulomb friction coefficient")
    restitution: float = Field(default=0.1, description="Bounce coefficient (0=no bounce)")
    density_g_per_mm3: float = Field(
        default=0.00124, description="Material density (PLA default)"
    )
    contact_material: str = Field(
        default="", description="Named material for Webots ContactProperties"
    )


class CollisionGeometry(BaseModel):
    """Simplified collision shape (cheaper than mesh for physics)."""
    type: str = Field(
        default="box",
        description="Shape type: box | cylinder | sphere | mesh",
    )
    dimensions_mm: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Box: (x,y,z), Cylinder: (radius,0,height), Sphere: (radius,0,0)",
    )
    origin_xyz: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0), description="Offset from link origin (mm)"
    )
    origin_rpy: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0), description="Rotation from link origin (rad)"
    )
    mesh_file: str = Field(
        default="", description="STL mesh file (only if type=mesh)"
    )


# ─── Printer ────────────────────────────────────────────────────────────────

class PrinterProfile(BaseModel):
    name: str = Field(description="Printer model name, e.g. 'Bambu Lab A1 Mini'")
    build_volume_mm: tuple[float, float, float] = Field(
        description="Build volume in mm (X, Y, Z)"
    )
    nozzle_diameter_mm: float = Field(default=0.4)
    layer_height_mm: float = Field(default=0.2)
    material: MaterialType = Field(default=MaterialType.PLA)
    wall_thickness_mm: float = Field(
        default=1.2, description="Wall thickness (3 perimeters at 0.4mm)"
    )
    tolerance_mm: float = Field(
        default=0.2, description="Print tolerance for mating surfaces"
    )


# ─── Reference Proportions (from Step 1 analysis) ───────────────────────────

class ReferenceProportions(BaseModel):
    """Proportional data from Gemini analysis of real-world reference."""
    source_vehicle: str = Field(default="", description="e.g. 'M1A1 Abrams'")
    scale: str = Field(default="1:26", description="Target scale ratio")
    real_dimensions_mm: dict = Field(
        default_factory=dict,
        description="Full-scale dimensions: hull_length, hull_width, etc.",
    )
    scaled_dimensions_mm: dict = Field(
        default_factory=dict,
        description="Dimensions at target scale",
    )
    proportional_ratios: dict = Field(
        default_factory=dict,
        description="Key ratios: hull_length_to_width, turret_length_to_hull_length, etc.",
    )
    shape_notes: list[dict] = Field(
        default_factory=list,
        description="Shape features: [{feature, description, angle_degrees}]",
    )


# ─── URDF Link (Part) ───────────────────────────────────────────────────────

class PartSpec(BaseModel):
    """A URDF link — a physical part with visual, collision, and inertial data."""
    id: str = Field(description="Unique identifier, e.g. 'chassis_hull'")
    name: str = Field(description="Human-readable name")
    scad_file: str = Field(default="", description="Relative path to .scad file")
    scad_code: str = Field(default="", description="Full OpenSCAD source code")
    category: str = Field(
        default="chassis",
        description="Part category: chassis | turret | console | track",
    )
    dimensions_mm: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Bounding box in mm (X, Y, Z)",
    )
    requires_splitting: bool = Field(
        default=False,
        description="True if part exceeds build volume",
    )
    split_parts: list[str] = Field(
        default_factory=list,
        description="IDs of sub-parts if split",
    )
    mass_grams: float = Field(default=0.0, description="Estimated mass")
    color: str = Field(
        default="#4a7c59", description="Hex color for visualization"
    )

    # Extended URDF fields
    inertial: Optional[InertialSpec] = Field(
        default=None, description="URDF inertial properties (auto-computed if None)"
    )
    collision: Optional[CollisionGeometry] = Field(
        default=None, description="Simplified collision shape (auto-generated if None)"
    )
    physics_material: Optional[PhysicsMaterial] = Field(
        default=None, description="Surface physics for simulation"
    )
    visual_origin_xyz: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0), description="Visual mesh offset from link origin"
    )
    visual_origin_rpy: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0), description="Visual mesh rotation from link origin"
    )


# ─── URDF Joint ──────────────────────────────────────────────────────────────

class JointLimits(BaseModel):
    """Structured joint limits (replaces the raw dict)."""
    lower: float = Field(default=-3.14159, description="Lower limit (rad or mm)")
    upper: float = Field(default=3.14159, description="Upper limit (rad or mm)")
    effort: float = Field(default=10.0, description="Max effort (N*m or N)")
    velocity: float = Field(default=1.0, description="Max velocity (rad/s or m/s)")


class JointSpec(BaseModel):
    """A URDF joint connecting two links."""
    name: str
    type: JointType
    parent_part: str = Field(description="References PartSpec.id")
    child_part: str = Field(description="References PartSpec.id")
    axis: tuple[float, float, float] = Field(
        description="Rotation/translation axis"
    )
    origin_xyz: tuple[float, float, float] = Field(
        description="Joint origin position in mm"
    )
    origin_rpy: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Roll, pitch, yaw in radians",
    )
    limits: Optional[JointLimits | dict] = Field(
        default=None,
        description="Joint limits (structured or dict for backwards compat)",
    )
    fastener: str = Field(
        default="m4_screw",
        description="Fastener type: m4_screw | snap_fit | press_fit | bayonet",
    )
    # Dynamics (optional, for simulation)
    damping: float = Field(default=0.0, description="Joint damping coefficient")
    friction: float = Field(default=0.0, description="Joint friction coefficient")


# ─── Electronics & Wiring ────────────────────────────────────────────────────

class WireConnection(BaseModel):
    """A single wire connection between components."""
    from_pin: str = Field(description="Source pin name, e.g. 'GPIO2'")
    to_component: str = Field(description="Target component ID")
    to_pin: str = Field(description="Target pin name")
    wire_color: str = Field(default="", description="Wire color for assembly")
    wire_gauge: str = Field(default="26AWG", description="Wire gauge")
    connector_type: str = Field(
        default="dupont",
        description="Connector: dupont | jst | screw_terminal | wago",
    )


class ElectronicComponent(BaseModel):
    """An electronic component mounted to a printed part."""
    id: str = Field(description="Unique identifier, e.g. 'hull_esp32cam'")
    type: str = Field(
        description="Component type: ESP32-CAM | MPU6050 | L298N | DRV8833 | N20-Motor | etc."
    )
    host_part: str = Field(description="PartSpec.id this mounts to")
    mount_position_mm: tuple[float, float, float] = Field(
        description="Mount position relative to host part origin"
    )
    mount_orientation_rpy: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Mount orientation in radians",
    )
    # Structured wiring (new)
    wiring: list[WireConnection] = Field(
        default_factory=list,
        description="Structured wire connections",
    )
    # GPIO pin assignments
    pin_map: dict = Field(
        default_factory=dict,
        description="GPIO pin assignments: {'function': 'GPIO_number'}",
    )
    # Legacy connections (backwards compat)
    connections: list[dict] = Field(
        default_factory=list,
        description="Legacy: list of {pin, wire_to, wire_color}",
    )
    # Power requirements
    voltage: float = Field(default=0.0, description="Operating voltage (V)")
    current_ma: float = Field(default=0.0, description="Max current draw (mA)")
    # Physical
    dimensions_mm: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Component bounding box (from electronics catalog if 0)",
    )
    mass_grams: float = Field(default=0.0, description="Component mass")


# ─── Assembly Constraints ────────────────────────────────────────────────────

class AssemblyConstraint(BaseModel):
    """A constraint that must be satisfied during assembly."""
    id: str = Field(description="Constraint identifier")
    description: str = Field(description="Human-readable constraint")
    constraint_type: str = Field(
        description="Type: no_soldering | printable_no_supports | screw_type | clearance"
    )
    value: str = Field(default="", description="Constraint value, e.g. 'M3' or '0.2mm'")
    applies_to: list[str] = Field(
        default_factory=list,
        description="Part IDs this constraint applies to (empty = all)",
    )


# ─── Master Specification ────────────────────────────────────────────────────

class RobotSpec(BaseModel):
    """Extended URDF — master specification and single source of truth.

    Captures kinematics (links + joints), electronics (components + wiring),
    printing constraints, reference proportions, and assembly rules.
    Used across the entire pipeline: NL → CAD → STL → URDF → Webots.
    """

    name: str = Field(description="Robot name, e.g. 'M1A1 Abrams'")
    version: str = Field(default="0.1.0", description="Semantic version")
    description: str = Field(default="")
    model_type: ModelType = Field(
        default=ModelType.TANK,
        description="Robot model type: tank (differential drive) or train (simple speed)",
    )

    # Printer constraints
    printer: PrinterProfile = Field(
        default_factory=lambda: PrinterProfile(
            name="Bambu Lab A1 Mini",
            build_volume_mm=(180.0, 180.0, 180.0),
        )
    )

    # URDF kinematic tree
    parts: list[PartSpec] = Field(default_factory=list)
    joints: list[JointSpec] = Field(default_factory=list)

    # Electronics & wiring
    electronics: list[ElectronicComponent] = Field(default_factory=list)

    # Assembly constraints (e.g., "NO SOLDERING", "M3 screws only")
    assembly_constraints: list[AssemblyConstraint] = Field(
        default_factory=list,
        description="Design rules that must be satisfied",
    )

    # Reference proportions (from Step 1 Gemini analysis)
    reference: Optional[ReferenceProportions] = Field(
        default=None,
        description="Proportional data from real-world reference analysis",
    )

    # Firmware configuration
    firmware_config: dict = Field(
        default_factory=dict,
        description="WiFi SSID, motor pins, servo angles, etc.",
    )

    # Metadata
    metadata: dict = Field(
        default_factory=dict,
        description="Arbitrary key-value pairs (scale, real_vehicle, etc.)",
    )

    # ─── Helper methods ──────────────────────────────────────────────────

    def get_part(self, part_id: str) -> PartSpec | None:
        """Look up a part by ID."""
        return next((p for p in self.parts if p.id == part_id), None)

    def get_electronics_for_part(self, part_id: str) -> list[ElectronicComponent]:
        """Get all electronics mounted to a specific part."""
        return [e for e in self.electronics if e.host_part == part_id]

    def total_mass_grams(self) -> float:
        """Compute total mass including parts and electronics."""
        part_mass = sum(p.mass_grams for p in self.parts)
        elec_mass = sum(e.mass_grams for e in self.electronics)
        return part_mass + elec_mass

    def validate_build_volume(self) -> list[str]:
        """Check which parts exceed the printer build volume."""
        bv = self.printer.build_volume_mm
        violations = []
        for part in self.parts:
            dims = part.dimensions_mm
            if any(d > b for d, b in zip(dims, bv)):
                violations.append(
                    f"{part.id}: {dims[0]:.0f}x{dims[1]:.0f}x{dims[2]:.0f}mm "
                    f"exceeds {bv[0]:.0f}x{bv[1]:.0f}x{bv[2]:.0f}mm"
                )
        return violations

    def kinematic_root(self) -> str | None:
        """Find the root link (parent of all, child of none)."""
        children = {j.child_part for j in self.joints}
        parents = {j.parent_part for j in self.joints}
        roots = parents - children
        return roots.pop() if roots else (self.parts[0].id if self.parts else None)
