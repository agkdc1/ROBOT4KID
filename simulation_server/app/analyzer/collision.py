"""Collision detection between parts."""

import logging
from pathlib import Path

from shared.schemas.simulation_feedback import FeedbackItem, SeverityLevel

logger = logging.getLogger(__name__)


def check_collisions(
    stl_paths: dict[str, Path],
) -> list[FeedbackItem]:
    """Check for collisions between parts.

    Args:
        stl_paths: Dict mapping part_id to STL file path.

    Returns:
        List of FeedbackItem for any collisions found.
    """
    feedback_items: list[FeedbackItem] = []

    try:
        import trimesh
    except ImportError:
        logger.warning("trimesh not installed, skipping collision check")
        return feedback_items

    meshes: dict[str, trimesh.Trimesh] = {}
    for part_id, path in stl_paths.items():
        try:
            mesh = trimesh.load(str(path), file_type="stl")
            if hasattr(mesh, "faces"):
                meshes[part_id] = mesh
        except Exception as e:
            logger.warning(f"Could not load {part_id} for collision check: {e}")

    part_ids = list(meshes.keys())
    for i in range(len(part_ids)):
        for j in range(i + 1, len(part_ids)):
            id_a = part_ids[i]
            id_b = part_ids[j]
            mesh_a = meshes[id_a]
            mesh_b = meshes[id_b]

            try:
                # Use bounding box overlap as quick check
                from trimesh.bounds import contains as bounds_contain

                # Simple AABB intersection check
                a_min, a_max = mesh_a.bounds[0], mesh_a.bounds[1]
                b_min, b_max = mesh_b.bounds[0], mesh_b.bounds[1]

                overlap = all(
                    a_min[k] <= b_max[k] and b_min[k] <= a_max[k]
                    for k in range(3)
                )

                if overlap:
                    # Bounding boxes overlap — flag as potential collision
                    feedback_items.append(FeedbackItem(
                        category="collision",
                        severity=SeverityLevel.WARNING,
                        part_id=id_a,
                        message=f"Bounding boxes overlap between '{id_a}' and '{id_b}'. Potential collision.",
                        data={"part_a": id_a, "part_b": id_b},
                        suggestion=f"Check that '{id_a}' and '{id_b}' do not intersect. Adjust positions or dimensions.",
                    ))
            except Exception as e:
                logger.warning(f"Collision check failed for {id_a}/{id_b}: {e}")

    return feedback_items
