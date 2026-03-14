"""Electronics specification schemas."""

from pydantic import BaseModel, Field


class WireConnection(BaseModel):
    pin: str = Field(description="Pin name on the component, e.g. 'GPIO12'")
    wire_to: str = Field(description="Target component and pin, e.g. 'hull_l9110:IA1'")
    wire_color: str = Field(default="black", description="Wire color for assembly guide")


class ComponentPlacement(BaseModel):
    component_id: str
    host_part_id: str
    position_mm: tuple[float, float, float]
    orientation_rpy: tuple[float, float, float] = (0.0, 0.0, 0.0)
    wiring: list[WireConnection] = Field(default_factory=list)
