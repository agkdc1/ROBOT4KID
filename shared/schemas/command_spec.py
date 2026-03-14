"""Universal command schema — supports multiple robot model types."""

from enum import Enum
from pydantic import BaseModel, Field


class ModelType(str, Enum):
    TANK = "tank"
    TRAIN = "train"


class DriveMode(str, Enum):
    DIFFERENTIAL = "differential"  # Tank: left_speed, right_speed
    SIMPLE = "simple"              # Train: speed only


class UniversalCommand(BaseModel):
    """Model-agnostic command envelope used at the app/server layer.
    Binary encoding is model-specific (TankCommand vs TrainCommand structs).
    """
    model_type: ModelType
    drive_mode: DriveMode

    # Simple drive (train)
    speed: int = Field(default=0, ge=-100, le=100, description="Speed for simple drive mode")

    # Differential drive (tank)
    left_speed: int = Field(default=0, ge=-100, le=100)
    right_speed: int = Field(default=0, ge=-100, le=100)

    # Tank-specific subsystems
    turret_angle: int = Field(default=0, ge=0, le=3600, description="Degrees x10")
    barrel_elevation: int = Field(default=-10, ge=-10, le=45)
    fire: bool = False
    camera_mode: int = Field(default=0, ge=0, le=2)

    # Train-specific subsystems
    horn: bool = False
    lights: int = Field(default=0, ge=0, le=3, description="0=off, 1=head, 2=tail, 3=both")
