"""Master robot specification — the single source of truth."""

from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


class MaterialType(str, Enum):
    PLA = "PLA"
    PETG = "PETG"
    TPU = "TPU"


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


class JointType(str, Enum):
    FIXED = "fixed"
    REVOLUTE = "revolute"
    CONTINUOUS = "continuous"
    PRISMATIC = "prismatic"


class JointSpec(BaseModel):
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
        description="Roll, pitch, yaw in radians"
    )
    limits: Optional[dict] = Field(
        default=None,
        description="Joint limits: {lower, upper, effort, velocity}",
    )
    fastener: str = Field(
        default="m4_screw",
        description="Fastener type: m4_screw | snap_fit | press_fit",
    )


class PartSpec(BaseModel):
    id: str = Field(description="Unique identifier, e.g. 'chassis_hull'")
    name: str = Field(description="Human-readable name")
    scad_file: str = Field(description="Relative path to .scad file")
    scad_code: str = Field(default="", description="Full OpenSCAD source code")
    category: str = Field(
        description="Part category: chassis | turret | console"
    )
    dimensions_mm: tuple[float, float, float] = Field(
        description="Bounding box in mm (X, Y, Z)"
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


class ElectronicComponent(BaseModel):
    id: str = Field(description="Unique identifier, e.g. 'hull_esp32cam'")
    type: str = Field(
        description="Component type: ESP32-CAM | MPU6050 | L9110 | etc."
    )
    host_part: str = Field(description="PartSpec.id this mounts to")
    mount_position_mm: tuple[float, float, float] = Field(
        description="Mount position relative to host part origin"
    )
    mount_orientation_rpy: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Mount orientation in radians",
    )
    connections: list[dict] = Field(
        default_factory=list,
        description="List of {pin, wire_to, wire_color}",
    )


class ModelType(str, Enum):
    TANK = "tank"
    TRAIN = "train"


class RobotSpec(BaseModel):
    """Master specification — the single source of truth for a robot design."""

    name: str = Field(description="Robot name, e.g. 'M1A1 Abrams'")
    version: str = Field(default="0.1.0", description="Semantic version")
    description: str = Field(default="")
    model_type: ModelType = Field(
        default=ModelType.TANK,
        description="Robot model type: tank (differential drive) or train (simple speed)",
    )
    printer: PrinterProfile = Field(
        default_factory=lambda: PrinterProfile(
            name="Bambu Lab A1 Mini",
            build_volume_mm=(180.0, 180.0, 180.0),
        )
    )
    parts: list[PartSpec] = Field(default_factory=list)
    joints: list[JointSpec] = Field(default_factory=list)
    electronics: list[ElectronicComponent] = Field(default_factory=list)
    firmware_config: dict = Field(
        default_factory=dict,
        description="WiFi SSID, motor pins, servo angles, etc.",
    )
    metadata: dict = Field(
        default_factory=dict,
        description="Arbitrary key-value pairs",
    )
