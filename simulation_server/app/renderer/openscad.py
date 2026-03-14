"""OpenSCAD CLI wrapper — renders SCAD code to STL."""

import asyncio
import logging
import shutil
import tempfile
from pathlib import Path

from simulation_server.app import config

logger = logging.getLogger(__name__)


def _find_openscad() -> str:
    """Find the OpenSCAD binary."""
    path = shutil.which(config.OPENSCAD_BIN)
    if path:
        return path
    # Common install locations
    for candidate in ["/usr/bin/openscad", "/usr/local/bin/openscad", "/snap/bin/openscad"]:
        if Path(candidate).exists():
            return candidate
    return config.OPENSCAD_BIN  # Let it fail with a clear error


async def render_scad_to_stl(
    scad_code: str,
    output_path: Path,
    parameters: dict | None = None,
    timeout: int | None = None,
) -> tuple[bool, str]:
    """Render OpenSCAD code to STL file.

    Returns (success, message).
    """
    timeout = timeout or config.OPENSCAD_TIMEOUT
    openscad_bin = _find_openscad()

    # Write SCAD code to temp file
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".scad", delete=False, dir=output_path.parent
    ) as f:
        f.write(scad_code)
        scad_path = Path(f.name)

    try:
        cmd = []
        if config.USE_XVFB:
            xvfb = shutil.which("xvfb-run")
            if xvfb:
                cmd.extend(["xvfb-run", "-a"])

        cmd.extend([
            openscad_bin,
            "-o", str(output_path),
            "--export-format", "binstl",
        ])

        # Add parameter overrides
        if parameters:
            for key, value in parameters.items():
                if isinstance(value, str):
                    cmd.extend(["-D", f"{key}=\"{value}\""])
                else:
                    cmd.extend(["-D", f"{key}={value}"])

        cmd.append(str(scad_path))

        logger.info(f"Running OpenSCAD: {' '.join(cmd)}")

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.communicate()
            return False, f"OpenSCAD render timed out after {timeout}s"

        stderr_text = stderr.decode("utf-8", errors="replace")

        if proc.returncode != 0:
            return False, f"OpenSCAD error (exit {proc.returncode}): {stderr_text}"

        if not output_path.exists() or output_path.stat().st_size == 0:
            return False, f"OpenSCAD produced no output. stderr: {stderr_text}"

        msg = f"Rendered successfully: {output_path.stat().st_size} bytes"
        if stderr_text.strip():
            msg += f" (warnings: {stderr_text.strip()[:200]})"
        return True, msg

    finally:
        scad_path.unlink(missing_ok=True)
