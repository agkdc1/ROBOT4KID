"""Shared Pydantic schemas for NL2Bot pipeline."""

from shared.schemas.robot_spec import (
    MaterialType,
    PrinterProfile,
    JointType,
    JointSpec,
    PartSpec,
    ElectronicComponent,
    ModelType,
    RobotSpec,
)
from shared.schemas.command_spec import (
    DriveMode,
    UniversalCommand,
)
from shared.schemas.simulation_request import SimulationRequest
from shared.schemas.simulation_feedback import (
    SeverityLevel,
    FeedbackItem,
    RenderResult,
    AssemblyResult,
    PhysicsResult,
    PrintabilityResult,
    SimulationFeedback,
)
from shared.schemas.part_spec import PartCategory, FastenerType
from shared.schemas.electronics_spec import WireConnection, ComponentPlacement

__all__ = [
    "MaterialType",
    "PrinterProfile",
    "JointType",
    "JointSpec",
    "PartSpec",
    "ElectronicComponent",
    "ModelType",
    "RobotSpec",
    "DriveMode",
    "UniversalCommand",
    "SimulationRequest",
    "SeverityLevel",
    "FeedbackItem",
    "RenderResult",
    "AssemblyResult",
    "PhysicsResult",
    "PrintabilityResult",
    "SimulationFeedback",
    "PartCategory",
    "FastenerType",
    "WireConnection",
    "ComponentPlacement",
]
