"""STL analysis utilities using trimesh."""

import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def analyze_stl(stl_path: Path) -> dict:
    """Analyze an STL file and return metrics.

    Returns dict with dimensions, volume, manifold status, triangle count.
    """
    try:
        import trimesh
    except ImportError:
        logger.warning("trimesh not installed, returning minimal analysis")
        size = stl_path.stat().st_size if stl_path.exists() else 0
        return {
            "dimensions_mm": (0.0, 0.0, 0.0),
            "volume_mm3": 0.0,
            "is_manifold": False,
            "triangle_count": 0,
            "stl_size_bytes": size,
            "center_of_mass": (0.0, 0.0, 0.0),
            "inertia_tensor": None,
            "error": "trimesh not installed",
        }

    try:
        mesh = trimesh.load(str(stl_path), file_type="stl")

        bounds = mesh.bounds  # [[min_x, min_y, min_z], [max_x, max_y, max_z]]
        dims = tuple(float(b) for b in (bounds[1] - bounds[0]))

        result = {
            "dimensions_mm": dims,
            "volume_mm3": float(mesh.volume) if mesh.is_volume else 0.0,
            "is_manifold": bool(mesh.is_watertight),
            "triangle_count": len(mesh.faces),
            "stl_size_bytes": stl_path.stat().st_size,
            "center_of_mass": tuple(float(c) for c in mesh.center_mass),
            "inertia_tensor": mesh.moment_inertia.tolist() if mesh.is_volume else None,
        }
        return result

    except Exception as e:
        logger.error(f"Failed to analyze STL {stl_path}: {e}")
        return {
            "dimensions_mm": (0.0, 0.0, 0.0),
            "volume_mm3": 0.0,
            "is_manifold": False,
            "triangle_count": 0,
            "stl_size_bytes": stl_path.stat().st_size if stl_path.exists() else 0,
            "center_of_mass": (0.0, 0.0, 0.0),
            "inertia_tensor": None,
            "error": str(e),
        }


def compute_overhang_percentage(stl_path: Path, max_angle_deg: float = 45.0) -> float:
    """Compute percentage of faces exceeding the overhang angle threshold."""
    try:
        import trimesh
        import numpy as np
    except ImportError:
        return 0.0

    try:
        mesh = trimesh.load(str(stl_path), file_type="stl")
        normals = mesh.face_normals

        # Overhang angle: angle between face normal and the negative Z axis
        # A face with normal pointing straight down (0, 0, -1) has 0 degree overhang
        # A face at 45 degrees from vertical needs support
        z_up = np.array([0, 0, 1])
        cos_angles = np.dot(normals, z_up)

        # Faces pointing downward (cos < 0) with angle > threshold need support
        import math
        cos_threshold = math.cos(math.radians(180 - max_angle_deg))
        overhanging = np.sum(cos_angles < cos_threshold)

        return float(overhanging / len(normals) * 100) if len(normals) > 0 else 0.0

    except Exception as e:
        logger.error(f"Overhang analysis failed: {e}")
        return 0.0
