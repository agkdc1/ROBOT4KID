"""Analyzer API endpoints."""

from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from shared.schemas.robot_spec import RobotSpec
from shared.schemas.simulation_feedback import PrintabilityResult, FeedbackItem
from simulation_server.app import config
from simulation_server.app.analyzer.printability import check_printability

router = APIRouter()


class ValidateRequest(BaseModel):
    robot_spec: RobotSpec


class ValidateResponse(BaseModel):
    valid: bool
    issues: list[str] = Field(default_factory=list)


@router.post("/validate", response_model=ValidateResponse)
async def validate_spec(request: ValidateRequest):
    """Validate a RobotSpec without running simulation."""
    issues: list[str] = []
    spec = request.robot_spec

    # Check for empty parts
    if not spec.parts:
        issues.append("No parts defined in specification.")

    # Check part IDs are unique
    part_ids = [p.id for p in spec.parts]
    if len(part_ids) != len(set(part_ids)):
        issues.append("Duplicate part IDs found.")

    # Validate joints reference valid parts
    for joint in spec.joints:
        if joint.parent_part not in part_ids:
            issues.append(f"Joint '{joint.name}' references unknown parent '{joint.parent_part}'.")
        if joint.child_part not in part_ids:
            issues.append(f"Joint '{joint.name}' references unknown child '{joint.child_part}'.")

    # Check electronics reference valid parts
    for elec in spec.electronics:
        if elec.host_part not in part_ids:
            issues.append(f"Electronic '{elec.id}' references unknown host part '{elec.host_part}'.")

    # Check build volume
    for part in spec.parts:
        bv = spec.printer.build_volume_mm
        dims = part.dimensions_mm
        if any(d > b for d, b in zip(dims, bv)) and not part.requires_splitting:
            issues.append(
                f"Part '{part.id}' ({dims[0]:.0f}x{dims[1]:.0f}x{dims[2]:.0f}mm) "
                f"exceeds build volume ({bv[0]:.0f}x{bv[1]:.0f}x{bv[2]:.0f}mm) "
                f"but requires_splitting=False."
            )

    return ValidateResponse(valid=len(issues) == 0, issues=issues)
