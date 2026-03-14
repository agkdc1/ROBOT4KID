"""Simulation feedback schema — returned by Simulation Server."""

from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from datetime import datetime, timezone


class SeverityLevel(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


class FeedbackItem(BaseModel):
    category: str = Field(
        description="Category: printability | collision | kinematics | physics"
    )
    severity: SeverityLevel
    part_id: Optional[str] = Field(
        default=None, description="Which part this applies to"
    )
    message: str = Field(description="Human-readable description")
    data: dict = Field(
        default_factory=dict, description="Machine-readable details"
    )
    suggestion: Optional[str] = Field(
        default=None, description="Suggested fix"
    )


class RenderResult(BaseModel):
    part_id: str
    stl_path: str = Field(description="Path to generated STL file")
    stl_size_bytes: int = 0
    dimensions_mm: tuple[float, float, float] = (0.0, 0.0, 0.0)
    volume_mm3: float = 0.0
    is_manifold: bool = True
    triangle_count: int = 0


class AssemblyResult(BaseModel):
    urdf_path: str = Field(description="Path to generated URDF file")
    total_mass_grams: float = 0.0
    center_of_mass: tuple[float, float, float] = (0.0, 0.0, 0.0)
    viewer_url: str = Field(
        default="", description="URL to 3D web viewer"
    )


class PhysicsResult(BaseModel):
    stable: bool = Field(description="Does the robot tip over?")
    max_speed_ms: float = Field(default=0.0, description="Simulated top speed m/s")
    turn_radius_mm: float = Field(default=0.0, description="Minimum turn radius")
    turret_range_deg: tuple[float, float] = Field(
        default=(0.0, 360.0), description="Azimuth range"
    )
    barrel_range_deg: tuple[float, float] = Field(
        default=(-10.0, 45.0), description="Elevation range"
    )
    simulation_log: list[dict] = Field(
        default_factory=list, description="Timestamped events"
    )


class PrintabilityResult(BaseModel):
    part_id: str
    fits_build_volume: bool = True
    overhang_percentage: float = Field(
        default=0.0, description="Percentage of faces > 45 deg overhang"
    )
    estimated_print_time_min: float = 0.0
    estimated_filament_grams: float = 0.0
    needs_supports: bool = False
    recommended_orientation: tuple[float, float, float] = Field(
        default=(0.0, 0.0, 0.0),
        description="Rotation for optimal print orientation",
    )


class SimulationFeedback(BaseModel):
    job_id: str
    status: str = Field(
        description="Status: completed | partial | failed"
    )
    render_results: list[RenderResult] = Field(default_factory=list)
    assembly_result: Optional[AssemblyResult] = None
    physics_result: Optional[PhysicsResult] = None
    printability_results: list[PrintabilityResult] = Field(default_factory=list)
    feedback_items: list[FeedbackItem] = Field(
        default_factory=list, description="Issues found"
    )
    overall_score: float = Field(
        default=0.0, description="0.0–1.0 feasibility score"
    )
    timestamp: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
