"""Blender Pro-Rendering module — generates cinematic renders via Cycles.

Integrates into the pipeline after Gate 2 approval. Produces box-art
quality images using PBR materials, HDRI lighting, 85mm portrait lens
with depth of field.

Requires Blender 3.6+ installed and accessible via PATH or BLENDER_BIN env var.
"""

import logging
import os
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)

RENDER_SCRIPT = Path(__file__).resolve().parents[3] / "system" / "render_pro.py"

# Render presets
PRESETS = {
    "hero": {
        "resolution": "1920x1080",
        "samples": 256,
        "parts": "full_assembly",
        "transparent": False,
        "description": "Hero shot — 3/4 view with ground plane and shadows",
    },
    "hero_4k": {
        "resolution": "3840x2160",
        "samples": 512,
        "parts": "full_assembly",
        "transparent": False,
        "description": "4K hero shot — highest quality",
    },
    "transparent": {
        "resolution": "1920x1080",
        "samples": 128,
        "parts": "full_assembly",
        "transparent": True,
        "description": "Transparent background for compositing",
    },
    "parts_grid": {
        "resolution": "1920x1080",
        "samples": 128,
        "parts": "all",
        "transparent": True,
        "description": "All parts rendered individually",
    },
}


def find_blender() -> str | None:
    """Find Blender executable."""
    # Check env var first
    blender_bin = os.environ.get("BLENDER_BIN", "")
    if blender_bin and os.path.exists(blender_bin):
        return blender_bin

    # Common Windows paths
    candidates = [
        "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe",
        "C:/Program Files/Blender Foundation/Blender 4.1/blender.exe",
        "C:/Program Files/Blender Foundation/Blender 4.0/blender.exe",
        "C:/Program Files/Blender Foundation/Blender 3.6/blender.exe",
    ]
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate

    # Try PATH
    import shutil
    return shutil.which("blender")


def render(
    stl_dir: Path,
    output_path: Path,
    preset: str = "hero",
    hdri_path: str = "",
    blender_bin: str | None = None,
    timeout: int = 600,
) -> bool:
    """Run Blender pro render.

    Args:
        stl_dir: Directory containing STL files.
        output_path: Output PNG path.
        preset: Render preset name.
        hdri_path: Optional HDRI environment map.
        blender_bin: Blender executable path.
        timeout: Max render time in seconds.

    Returns:
        True if render succeeded.
    """
    blender = blender_bin or find_blender()
    if not blender:
        logger.warning("Blender not found — skipping pro render")
        return False

    if not RENDER_SCRIPT.exists():
        logger.error(f"Render script not found: {RENDER_SCRIPT}")
        return False

    cfg = PRESETS.get(preset, PRESETS["hero"])

    cmd = [
        blender,
        "--background",
        "--python", str(RENDER_SCRIPT),
        "--",
        "--stl-dir", str(stl_dir),
        "--output", str(output_path),
        "--resolution", cfg["resolution"],
        "--samples", str(cfg["samples"]),
        "--parts", cfg["parts"],
    ]
    if cfg.get("transparent"):
        cmd.append("--transparent")
    if hdri_path:
        cmd.extend(["--hdri", hdri_path])

    logger.info(f"Blender render: preset={preset}, output={output_path}")
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
        )
        if output_path.exists() and output_path.stat().st_size > 0:
            logger.info(f"Render complete: {output_path} ({output_path.stat().st_size} bytes)")
            return True
        else:
            logger.warning(f"Render failed: {result.stderr[:500]}")
            return False
    except subprocess.TimeoutExpired:
        logger.warning(f"Render timed out after {timeout}s")
        return False
    except Exception as e:
        logger.warning(f"Render error: {e}")
        return False


async def render_pro_shots(
    job_dir: Path,
    presets: list[str] | None = None,
) -> dict[str, Path]:
    """Render multiple pro shots for a job.

    Args:
        job_dir: Simulation job directory with STL outputs.
        presets: List of preset names to render.

    Returns:
        Dict mapping preset name to output PNG path.
    """
    stl_dir = job_dir / "output"
    renders_dir = job_dir / "renders"
    renders_dir.mkdir(exist_ok=True)

    presets = presets or ["hero", "transparent"]
    results = {}

    for preset in presets:
        output_path = renders_dir / f"pro_{preset}.png"
        if render(stl_dir, output_path, preset=preset):
            results[preset] = output_path

    return results
