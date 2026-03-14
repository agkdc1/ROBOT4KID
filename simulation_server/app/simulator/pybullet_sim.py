"""PyBullet physics simulation (placeholder — requires pybullet install)."""

import logging
from pathlib import Path
from shared.schemas.simulation_feedback import PhysicsResult

logger = logging.getLogger(__name__)


async def run_physics_simulation(
    urdf_path: Path,
    duration_s: float = 5.0,
    time_step: float = 1.0 / 240,
) -> PhysicsResult:
    """Run a physics simulation using PyBullet.

    Currently a placeholder that returns a default result.
    Full implementation requires pybullet to be installed.
    """
    logger.info(f"Physics simulation requested for {urdf_path} ({duration_s}s)")

    try:
        import pybullet as p
        import pybullet_data

        physics_client = p.connect(p.DIRECT)
        p.setAdditionalSearchPath(pybullet_data.getDataPath())
        p.setGravity(0, 0, -9.81)
        p.setTimeStep(time_step)

        # Load ground plane
        plane_id = p.loadURDF("plane.urdf")

        # Load robot
        robot_id = p.loadURDF(
            str(urdf_path),
            basePosition=[0, 0, 0.1],
            useFixedBase=False,
        )

        # Run simulation
        log_entries = []
        stable = True
        steps = int(duration_s / time_step)

        for step in range(steps):
            p.stepSimulation()

            if step % 240 == 0:  # Log every second
                pos, orn = p.getBasePositionAndOrientation(robot_id)
                euler = p.getEulerFromQuaternion(orn)
                t = step * time_step
                log_entries.append({
                    "time": round(t, 2),
                    "position": [round(v, 4) for v in pos],
                    "orientation_deg": [round(v * 57.2958, 1) for v in euler],
                })

                # Check if tipped over (roll or pitch > 45 degrees)
                if abs(euler[0]) > 0.785 or abs(euler[1]) > 0.785:
                    stable = False

        p.disconnect()

        return PhysicsResult(
            stable=stable,
            max_speed_ms=0.0,
            turn_radius_mm=0.0,
            turret_range_deg=(0.0, 360.0),
            barrel_range_deg=(-10.0, 45.0),
            simulation_log=log_entries,
        )

    except ImportError:
        logger.warning("pybullet not installed, returning placeholder result")
        return PhysicsResult(
            stable=True,
            max_speed_ms=0.0,
            turn_radius_mm=0.0,
            simulation_log=[{"note": "pybullet not installed, placeholder result"}],
        )
    except Exception as e:
        logger.error(f"Physics simulation failed: {e}")
        return PhysicsResult(
            stable=False,
            simulation_log=[{"error": str(e)}],
        )
