"""Simulation request schema — sent from Planning Server to Simulation Server."""

from pydantic import BaseModel, Field
from typing import Optional

from shared.schemas.robot_spec import RobotSpec


class SimulationRequest(BaseModel):
    job_id: str = Field(description="UUID assigned by caller")
    robot_spec: RobotSpec = Field(description="The full robot specification")
    simulation_type: str = Field(
        default="full",
        description="Type: render | assemble | physics | full",
    )
    parameters: dict = Field(
        default_factory=dict,
        description="Simulation-specific parameters",
    )
    callback_url: Optional[str] = Field(
        default=None,
        description="POST feedback here when done",
    )
