"""3MF export module — modern replacement for STL with metadata support.

Converts individual STL files into a single .3mf archive containing:
- Mesh data in 3MF XML format
- Print orientation metadata (transform matrices on build items)
- Infill zone tagging via 3MF slice extension metadata
- Unit specification (millimeter)

3MF is a ZIP archive with structure:
    [Content_Types].xml
    _rels/.rels
    3D/3dmodel.model
"""

from __future__ import annotations

import math
import struct
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CONTENT_TYPES_XML = """\
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml" />
</Types>"""

RELS_XML = """\
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel" />
</Relationships>"""

NS_3MF = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
NS_SLIC3R = "http://schemas.slic3r.org/3mf/2017/06"

# Orientation presets: each is a 4x3 affine matrix (row-major, last column is
# translation which we leave at origin).  The 3MF spec stores a 3x4 matrix
# in row-major as 12 floats: m00 m01 m02 m10 m11 m12 m20 m21 m22 m30 m31 m32
# where (m30, m31, m32) is translation.
ORIENTATION_MATRICES: dict[str, str] = {
    # Identity — part lies flat on XY build plate (default).
    "flat": "1 0 0 0 1 0 0 0 1 0 0 0",
    # 90° rotation around X-axis — part stands upright (Z-up becomes Y-up).
    # Rx(90): [[1,0,0],[0,0,-1],[0,1,0]]
    "vertical": "1 0 0 0 0 1 0 -1 0 0 0 0",
    # 180° rotation around X-axis — part is inverted (top faces build plate).
    # Rx(180): [[1,0,0],[0,-1,0],[0,0,-1]]
    "inverted": "1 0 0 0 -1 0 0 0 -1 0 0 0",
}

# Default orientation map for tank parts.
TANK_ORIENTATIONS: dict[str, str] = {
    "barrel": "vertical",
    "gun_barrel": "vertical",
    "hull_front": "flat",
    "hull_rear": "flat",
    "turret_body": "inverted",
    "track_left": "flat",
    "track_right": "flat",
    "track_assembly_left": "flat",
    "track_assembly_right": "flat",
    "electronics_bay": "flat",
    "console_cradle": "flat",
}

# Default infill overrides for tank parts (percentage).
TANK_INFILL_ZONES: dict[str, int] = {
    "gun_mantlet": 100,
    "barrel": 100,
    "gun_barrel": 100,
    "axle": 100,
    "drive_sprocket": 100,
    "idler_wheel": 100,
}

# Train defaults.
TRAIN_ORIENTATIONS: dict[str, str] = {
    "locomotive_top": "inverted",
    "locomotive_bottom": "flat",
    "motor_mount": "flat",
    "battery_bay": "flat",
    "camera_mount": "flat",
}

TRAIN_INFILL_ZONES: dict[str, int] = {
    "motor_mount": 100,
    "camera_mount": 80,
}


# ---------------------------------------------------------------------------
# STL binary reader (fallback when trimesh is unavailable)
# ---------------------------------------------------------------------------

def _read_stl_binary(path: Path) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int]]]:
    """Read a binary STL and return (vertices, faces).

    Deduplicates vertices by exact float match for compact 3MF output.
    """
    data = path.read_bytes()

    # Check for ASCII STL
    if data[:5] == b"solid" and b"facet" in data[:1000]:
        raise ValueError(
            f"ASCII STL not supported by built-in reader; install trimesh: {path}"
        )

    num_triangles = struct.unpack_from("<I", data, 80)[0]
    vertex_map: dict[tuple[float, float, float], int] = {}
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int]] = []

    offset = 84
    for _ in range(num_triangles):
        # Skip normal (3 floats = 12 bytes)
        offset += 12
        tri_indices: list[int] = []
        for _ in range(3):
            x, y, z = struct.unpack_from("<fff", data, offset)
            offset += 12
            key = (x, y, z)
            if key not in vertex_map:
                vertex_map[key] = len(vertices)
                vertices.append(key)
            tri_indices.append(vertex_map[key])
        faces.append((tri_indices[0], tri_indices[1], tri_indices[2]))
        # Skip attribute byte count
        offset += 2

    return vertices, faces


def _load_mesh(path: Path) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int]]]:
    """Load an STL file, returning (vertices, faces).

    Tries trimesh first (handles ASCII + binary), falls back to built-in
    binary reader.
    """
    try:
        import trimesh  # type: ignore[import-untyped]

        mesh = trimesh.load(str(path), file_type="stl", force="mesh")
        verts = [(float(v[0]), float(v[1]), float(v[2])) for v in mesh.vertices]
        tris = [(int(f[0]), int(f[1]), int(f[2])) for f in mesh.faces]
        return verts, tris
    except ImportError:
        return _read_stl_binary(path)


# ---------------------------------------------------------------------------
# 3MF XML builder
# ---------------------------------------------------------------------------

def _build_model_xml(
    meshes: dict[str, tuple[list[tuple[float, float, float]], list[tuple[int, int, int]]]],
    orientations: dict[str, str],
    infill_zones: dict[str, int],
    unit: str,
) -> bytes:
    """Build the 3D/3dmodel.model XML document."""
    model = ET.Element("model")
    model.set("xmlns", NS_3MF)
    model.set("xmlns:slic3rpe", NS_SLIC3R)
    model.set("unit", unit)
    model.set("xml:lang", "en-US")

    # Metadata
    meta_title = ET.SubElement(model, "metadata")
    meta_title.set("name", "Title")
    meta_title.text = "ROBOT4KID Assembly"

    meta_app = ET.SubElement(model, "metadata")
    meta_app.set("name", "Application")
    meta_app.text = "ROBOT4KID Simulation Server"

    resources = ET.SubElement(model, "resources")
    build = ET.SubElement(model, "build")

    for obj_id, (part_id, (verts, tris)) in enumerate(meshes.items(), start=1):
        obj = ET.SubElement(resources, "object")
        obj.set("id", str(obj_id))
        obj.set("type", "model")
        obj.set("name", part_id)

        # Infill metadata (slic3r PE / PrusaSlicer extension)
        if part_id in infill_zones:
            pct = infill_zones[part_id]
            config = ET.SubElement(obj, "slic3rpe:config")
            opt = ET.SubElement(config, "slic3rpe:option")
            opt.set("key", "fill_density")
            opt.text = f"{pct}%"

        mesh_el = ET.SubElement(obj, "mesh")

        # Vertices
        vertices_el = ET.SubElement(mesh_el, "vertices")
        for x, y, z in verts:
            v_el = ET.SubElement(vertices_el, "vertex")
            v_el.set("x", f"{x:.6f}")
            v_el.set("y", f"{y:.6f}")
            v_el.set("z", f"{z:.6f}")

        # Triangles
        triangles_el = ET.SubElement(mesh_el, "triangles")
        for v1, v2, v3 in tris:
            t_el = ET.SubElement(triangles_el, "triangle")
            t_el.set("v1", str(v1))
            t_el.set("v2", str(v2))
            t_el.set("v3", str(v3))

        # Build item with orientation transform
        item = ET.SubElement(build, "item")
        item.set("objectid", str(obj_id))
        orientation_key = orientations.get(part_id, "flat")
        transform = ORIENTATION_MATRICES.get(orientation_key, ORIENTATION_MATRICES["flat"])
        item.set("transform", transform)

    ET.indent(model, space="  ")
    return b'<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(model, encoding="unicode").encode("utf-8")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def export_3mf(
    stl_files: dict[str, Path],
    output_path: Path,
    orientations: dict[str, str] | None = None,
    infill_zones: dict[str, int] | None = None,
    unit: str = "millimeter",
) -> Path:
    """Package STL files into a single .3mf archive.

    Args:
        stl_files: Mapping of part_id to STL file path.
        output_path: Where to write the .3mf file.
        orientations: Optional mapping of part_id to orientation preset
            ("flat", "vertical", "inverted"). Parts not listed default to "flat".
        infill_zones: Optional mapping of part_id to infill percentage.
            Used by PrusaSlicer/BambuStudio for per-object infill overrides.
        unit: Length unit for the 3MF model (default: "millimeter").

    Returns:
        The output_path after successful write.
    """
    orientations = orientations or {}
    infill_zones = infill_zones or {}

    # Load all meshes
    meshes: dict[str, tuple[list[tuple[float, float, float]], list[tuple[int, int, int]]]] = {}
    for part_id, stl_path in stl_files.items():
        if not stl_path.exists():
            raise FileNotFoundError(f"STL file not found for part '{part_id}': {stl_path}")
        meshes[part_id] = _load_mesh(stl_path)

    if not meshes:
        raise ValueError("No STL files provided")

    # Build XML
    model_xml = _build_model_xml(meshes, orientations, infill_zones, unit)

    # Write ZIP
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES_XML)
        zf.writestr("_rels/.rels", RELS_XML)
        zf.writestr("3D/3dmodel.model", model_xml)

    return output_path


def _collect_stl_files(job_dir: Path) -> dict[str, Path]:
    """Scan a job's output directory for STL files and return part_id -> path."""
    output_dir = job_dir / "output"
    if not output_dir.exists():
        raise FileNotFoundError(f"Output directory not found: {output_dir}")

    stl_files: dict[str, Path] = {}
    for stl_path in sorted(output_dir.glob("*.stl")):
        part_id = stl_path.stem  # e.g. "hull_front" from "hull_front.stl"
        stl_files[part_id] = stl_path

    if not stl_files:
        raise FileNotFoundError(f"No STL files found in {output_dir}")

    return stl_files


def export_tank_3mf(job_dir: Path) -> Path:
    """Export all tank parts from a job directory as a single .3mf.

    Applies tank-specific orientation presets and infill zone tags.
    """
    stl_files = _collect_stl_files(job_dir)
    output_path = job_dir / "output" / "tank_assembly.3mf"

    return export_3mf(
        stl_files=stl_files,
        output_path=output_path,
        orientations=TANK_ORIENTATIONS,
        infill_zones=TANK_INFILL_ZONES,
        unit="millimeter",
    )


def export_train_3mf(job_dir: Path) -> Path:
    """Export all train parts from a job directory as a single .3mf.

    Applies train-specific orientation presets and infill zone tags.
    """
    stl_files = _collect_stl_files(job_dir)
    output_path = job_dir / "output" / "train_assembly.3mf"

    return export_3mf(
        stl_files=stl_files,
        output_path=output_path,
        orientations=TRAIN_ORIENTATIONS,
        infill_zones=TRAIN_INFILL_ZONES,
        unit="millimeter",
    )
