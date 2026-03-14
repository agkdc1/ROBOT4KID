"""Trajectory equation and RL coefficient training for FCS.

Physics model:
  barrel_angle = arctan(g * R / (2 * v^2)) * gravity_factor
                 + drag_factor * R^2
                 - hopup_factor * (rpm / 1000) / v
                 + motion_factor * chassis_speed * cos(turret_angle)
                 + bias

Where:
  g = 9.81 m/s^2
  R = range in meters
  v = ball speed in m/s
  rpm = hop-up backspin RPM
  chassis_speed = m/s
  turret_angle = degrees

The RL training adjusts the 5 coefficients (gravity_factor, drag_factor,
hopup_factor, motion_factor, bias) by minimizing the error between
predicted impact and actual impact.
"""

import json
import math
import logging
from pathlib import Path
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

COEFFICIENTS_PATH = Path(__file__).resolve().parent / "coefficients.json"


class TrajectoryCoefficients(BaseModel):
    gravity_factor: float = Field(default=1.0)
    drag_factor: float = Field(default=0.001)
    hopup_factor: float = Field(default=0.5)
    motion_factor: float = Field(default=0.1)
    bias: float = Field(default=0.0)


class ShotRecord(BaseModel):
    range_meters: float
    barrel_angle: float
    ball_speed: float
    hopup_rpm: float
    chassis_speed: float
    turret_angle: float
    actual_impact_y: float  # vertical offset from target center (positive = high)


def predict_barrel_angle(
    range_meters: float,
    ball_speed: float,
    hopup_rpm: float,
    chassis_speed: float,
    turret_angle: float,
    coefficients: TrajectoryCoefficients,
) -> float:
    """Predict optimal barrel angle using physics + tuned coefficients."""
    c = coefficients
    g = 9.81 * c.gravity_factor
    v = max(ball_speed, 1.0)
    r = range_meters

    angle = math.atan(g * r / (2 * v * v)) * (180 / math.pi)
    angle += c.drag_factor * r * r
    angle -= c.hopup_factor * (hopup_rpm / 1000.0) / v
    turret_rad = turret_angle * math.pi / 180
    angle += c.motion_factor * chassis_speed * math.cos(turret_rad)
    angle += c.bias

    return max(-10.0, min(45.0, angle))


def train_coefficients(
    shots: list[ShotRecord],
    current: TrajectoryCoefficients | None = None,
    learning_rate: float = 0.01,
    epochs: int = 100,
) -> TrajectoryCoefficients:
    """Simple gradient descent to tune trajectory coefficients.

    For each shot, compute the error between predicted and actual impact,
    then adjust coefficients to minimize squared error.

    This is a lightweight RL approach — works on CPU, no ML framework needed.
    For production, replace with PPO or similar via PyTorch.
    """
    if not shots:
        return current or TrajectoryCoefficients()

    c = current or TrajectoryCoefficients()
    params = [c.gravity_factor, c.drag_factor, c.hopup_factor, c.motion_factor, c.bias]

    for epoch in range(epochs):
        grads = [0.0] * 5
        total_loss = 0.0

        for shot in shots:
            # Predicted angle
            pred = predict_barrel_angle(
                shot.range_meters, shot.ball_speed, shot.hopup_rpm,
                shot.chassis_speed, shot.turret_angle,
                TrajectoryCoefficients(
                    gravity_factor=params[0], drag_factor=params[1],
                    hopup_factor=params[2], motion_factor=params[3],
                    bias=params[4],
                ),
            )

            # Error: if actual impact was high, we need less angle (and vice versa)
            # actual_impact_y > 0 means shot went high → reduce angle
            error = shot.actual_impact_y  # positive = too high

            total_loss += error * error

            # Numerical gradient for each parameter
            eps = 0.001
            for i in range(5):
                p_plus = params.copy()
                p_plus[i] += eps
                pred_plus = predict_barrel_angle(
                    shot.range_meters, shot.ball_speed, shot.hopup_rpm,
                    shot.chassis_speed, shot.turret_angle,
                    TrajectoryCoefficients(
                        gravity_factor=p_plus[0], drag_factor=p_plus[1],
                        hopup_factor=p_plus[2], motion_factor=p_plus[3],
                        bias=p_plus[4],
                    ),
                )
                # How does changing this param affect the prediction?
                # We want to adjust so error → 0
                grads[i] += error * (pred_plus - pred) / eps

        # Update params
        for i in range(5):
            params[i] -= learning_rate * grads[i] / len(shots)

        if epoch % 20 == 0:
            logger.info(f"Epoch {epoch}: loss={total_loss/len(shots):.6f}")

    result = TrajectoryCoefficients(
        gravity_factor=params[0], drag_factor=params[1],
        hopup_factor=params[2], motion_factor=params[3],
        bias=params[4],
    )

    # Save to disk
    COEFFICIENTS_PATH.write_text(result.model_dump_json(indent=2))
    logger.info(f"Trained coefficients saved: {result}")

    return result


def load_coefficients() -> TrajectoryCoefficients:
    """Load coefficients from disk, or return defaults."""
    if COEFFICIENTS_PATH.exists():
        data = json.loads(COEFFICIENTS_PATH.read_text())
        return TrajectoryCoefficients.model_validate(data)
    return TrajectoryCoefficients()
