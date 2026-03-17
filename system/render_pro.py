"""Blender Pro-Rendering Pipeline — Box Art Quality Renders.

Usage:
    blender -b -P system/render_pro.py -- --stl-dir <path> [--output <path>] [--hdri <path>]

Generates cinematic renders of robot models using Cycles engine with:
- HDRI environment lighting
- PBR materials (painted metal, matte tracks, clear-coat)
- 85mm portrait lens with depth of field
- OptiX/OIDN denoising
- Automatic camera framing from bounding box

Requires Blender 3.6+ installed.
"""

import bpy
import bmesh
import math
import os
import sys
from pathlib import Path
from mathutils import Vector


# ─── Configuration ───────────────────────────────────────────────────────────

DEFAULT_RESOLUTION = (1920, 1080)
DEFAULT_SAMPLES = 256
FOCAL_LENGTH_MM = 85  # Portrait lens — heroic, minimal distortion
F_STOP = 4.0  # Shallow DoF for professional bokeh
CAMERA_ELEVATION_DEG = 25  # Camera angle above horizon
CAMERA_AZIMUTH_DEG = 35  # 3/4 view angle

# PBR Material presets
MATERIALS = {
    # Painted hull/turret — olive drab with clear coat
    "paint_olive": {
        "base_color": (0.22, 0.27, 0.14, 1.0),
        "metallic": 0.0,
        "roughness": 0.35,
        "clearcoat": 0.3,
        "clearcoat_roughness": 0.1,
    },
    # Darker turret paint
    "paint_dark_olive": {
        "base_color": (0.18, 0.22, 0.10, 1.0),
        "metallic": 0.0,
        "roughness": 0.3,
        "clearcoat": 0.4,
        "clearcoat_roughness": 0.08,
    },
    # Gun barrel — dark metal
    "metal_barrel": {
        "base_color": (0.15, 0.15, 0.13, 1.0),
        "metallic": 1.0,
        "roughness": 0.2,
        "clearcoat": 0.0,
        "clearcoat_roughness": 0.0,
    },
    # Tracks — matte black rubber
    "track_rubber": {
        "base_color": (0.05, 0.05, 0.04, 1.0),
        "metallic": 0.0,
        "roughness": 0.8,
        "clearcoat": 0.0,
        "clearcoat_roughness": 0.0,
    },
    # Electronics — PCB green
    "electronics_pcb": {
        "base_color": (0.05, 0.35, 0.12, 1.0),
        "metallic": 0.0,
        "roughness": 0.4,
        "clearcoat": 0.5,
        "clearcoat_roughness": 0.15,
    },
    # Console — dark grey plastic
    "plastic_dark": {
        "base_color": (0.08, 0.08, 0.08, 1.0),
        "metallic": 0.0,
        "roughness": 0.5,
        "clearcoat": 0.2,
        "clearcoat_roughness": 0.2,
    },
}

# Part name → material mapping (substring match)
PART_MATERIAL_MAP = [
    ("track", "track_rubber"),
    ("barrel", "metal_barrel"),
    ("gun", "metal_barrel"),
    ("elec", "electronics_pcb"),
    ("console", "plastic_dark"),
    ("turret", "paint_dark_olive"),
    ("hull", "paint_olive"),
    ("assembly", "paint_olive"),
]


# ─── Parse CLI Arguments ────────────────────────────────────────────────────

def parse_args():
    """Parse arguments after '--' in blender command line."""
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    import argparse
    parser = argparse.ArgumentParser(description="Blender Pro Renderer")
    parser.add_argument("--stl-dir", required=True, help="Directory containing STL files")
    parser.add_argument("--output", default="render_pro.png", help="Output image path")
    parser.add_argument("--hdri", default="", help="Path to HDRI environment map (.hdr/.exr)")
    parser.add_argument("--resolution", default="1920x1080", help="Resolution WxH")
    parser.add_argument("--samples", type=int, default=DEFAULT_SAMPLES, help="Render samples")
    parser.add_argument("--parts", default="full_assembly", help="Comma-separated part names (or 'all')")
    parser.add_argument("--transparent", action="store_true", help="Transparent background")
    return parser.parse_args(argv)


# ─── Scene Setup ─────────────────────────────────────────────────────────────

def clear_scene():
    """Remove all default objects."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    # Remove orphan data
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)


def setup_render_engine(samples=DEFAULT_SAMPLES):
    """Configure Cycles with GPU acceleration, OptiX denoising, and optimized sampling."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"

    # ─── GPU Acceleration (OptiX > CUDA > HIP > CPU) ────────────────────
    gpu_active = False
    active_compute_type = "NONE"
    prefs = bpy.context.preferences.addons.get("cycles")
    if prefs:
        cprefs = prefs.preferences
        for compute_type in ["OPTIX", "CUDA", "HIP"]:
            try:
                cprefs.compute_device_type = compute_type
                cprefs.get_devices()
                gpu_devices = [d for d in cprefs.devices if d.type != "CPU"]
                if gpu_devices:
                    # Activate ALL available GPUs for multi-GPU support
                    for device in cprefs.devices:
                        device.use = True
                    scene.cycles.device = "GPU"
                    gpu_active = True
                    active_compute_type = compute_type
                    gpu_names = [d.name for d in gpu_devices]
                    print(f"[render_pro] GPU: {compute_type} — {', '.join(gpu_names)}")
                    break
            except Exception:
                continue

    if not gpu_active:
        scene.cycles.device = "CPU"
        print("[render_pro] WARNING: No GPU detected — falling back to CPU rendering")

    # ─── Sampling ────────────────────────────────────────────────────────
    scene.cycles.samples = samples

    # Adaptive sampling — stop calculating clean pixels early
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.05  # Noise threshold (lower = cleaner)
    scene.cycles.adaptive_min_samples = 16  # Minimum before adaptive kicks in

    # ─── AI Denoising ────────────────────────────────────────────────────
    scene.cycles.use_denoising = True
    if active_compute_type == "OPTIX":
        # OptiX AI Denoiser — fastest on NVIDIA RTX
        scene.cycles.denoiser = "OPTIX"
        print("[render_pro] Denoiser: OptiX AI")
    else:
        # OpenImageDenoise — works on CPU and all GPUs
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
        print("[render_pro] Denoiser: OpenImageDenoise")

    # Viewport denoising (for interactive preview if not headless)
    scene.cycles.use_preview_denoising = True
    scene.cycles.preview_denoiser = "OPENIMAGEDENOISE"

    # ─── Light Path Optimization (Hero Shot) ─────────────────────────────
    scene.cycles.max_bounces = 6       # Total max bounces
    scene.cycles.diffuse_bounces = 2   # Diffuse (matte surfaces)
    scene.cycles.glossy_bounces = 4    # Glossy (metal, clearcoat)
    scene.cycles.transmission_bounces = 2  # Transmission (glass — minimal for our models)
    scene.cycles.volume_bounces = 0    # Volume (smoke/fog — not used)
    scene.cycles.transparent_max_bounces = 4  # Transparent (alpha)

    # ─── Performance ─────────────────────────────────────────────────────
    # Persistent data — keep scene in GPU memory between re-renders
    scene.render.use_persistent_data = True

    # Tile size — Blender 3.0+ uses automatic optimal tiling for GPU
    # No need to set manually; the default is optimized per device

    # ─── Film ────────────────────────────────────────────────────────────
    scene.render.film_transparent = False  # Will be overridden if --transparent


def setup_hdri(hdri_path=""):
    """Setup HDRI environment lighting."""
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    nodes.clear()

    if hdri_path and os.path.exists(hdri_path):
        # Use provided HDRI
        env_tex = nodes.new("ShaderNodeTexEnvironment")
        env_tex.image = bpy.data.images.load(hdri_path)
        env_tex.location = (-300, 300)

        mapping = nodes.new("ShaderNodeMapping")
        mapping.location = (-500, 300)
        tex_coord = nodes.new("ShaderNodeTexCoord")
        tex_coord.location = (-700, 300)

        bg = nodes.new("ShaderNodeBackground")
        bg.inputs["Strength"].default_value = 1.0
        bg.location = (0, 300)

        output = nodes.new("ShaderNodeOutputWorld")
        output.location = (200, 300)

        links.new(tex_coord.outputs["Generated"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], env_tex.inputs["Vector"])
        links.new(env_tex.outputs["Color"], bg.inputs["Color"])
        links.new(bg.outputs["Background"], output.inputs["Surface"])
        print(f"[render_pro] HDRI: {hdri_path}")
    else:
        # Studio lighting setup (no HDRI file needed)
        bg = nodes.new("ShaderNodeBackground")
        bg.inputs["Color"].default_value = (0.02, 0.02, 0.03, 1.0)  # Dark studio
        bg.inputs["Strength"].default_value = 0.3
        bg.location = (0, 300)

        output = nodes.new("ShaderNodeOutputWorld")
        output.location = (200, 300)
        links.new(bg.outputs["Background"], output.inputs["Surface"])

        # Add 3-point studio lighting
        _add_studio_lights()
        print("[render_pro] Studio lighting (no HDRI)")


def _add_studio_lights():
    """Create a 3-point studio lighting setup."""
    lights = [
        # Key light — warm, strong, high and to the right
        {"name": "Key", "type": "AREA", "energy": 500, "size": 2.0,
         "location": (3, -2, 3), "color": (1.0, 0.95, 0.9)},
        # Fill light — cool, softer, from the left
        {"name": "Fill", "type": "AREA", "energy": 150, "size": 3.0,
         "location": (-3, -1, 2), "color": (0.85, 0.9, 1.0)},
        # Rim/back light — strong, from behind to create edge definition
        {"name": "Rim", "type": "AREA", "energy": 300, "size": 1.5,
         "location": (-1, 3, 2.5), "color": (1.0, 1.0, 1.0)},
    ]
    for cfg in lights:
        bpy.ops.object.light_add(type=cfg["type"], location=cfg["location"])
        light = bpy.context.object
        light.name = cfg["name"]
        light.data.energy = cfg["energy"]
        light.data.color = cfg["color"][:3]
        if cfg["type"] == "AREA":
            light.data.size = cfg["size"]
        # Point lights at origin
        direction = Vector((0, 0, 0)) - Vector(cfg["location"])
        light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


# ─── Material Creation ───────────────────────────────────────────────────────

def create_pbr_material(name, preset):
    """Create a Principled BSDF material from preset dict."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if not bsdf:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")

    bsdf.inputs["Base Color"].default_value = preset["base_color"]
    bsdf.inputs["Metallic"].default_value = preset["metallic"]
    bsdf.inputs["Roughness"].default_value = preset["roughness"]

    # Clear coat (Blender 4.x uses "Coat Weight" / "Coat Roughness",
    # older uses "Clearcoat" / "Clearcoat Roughness")
    for cc_name in ["Coat Weight", "Clearcoat"]:
        if cc_name in bsdf.inputs:
            bsdf.inputs[cc_name].default_value = preset.get("clearcoat", 0)
            break
    for ccr_name in ["Coat Roughness", "Clearcoat Roughness"]:
        if ccr_name in bsdf.inputs:
            bsdf.inputs[ccr_name].default_value = preset.get("clearcoat_roughness", 0)
            break

    return mat


def assign_material(obj, part_name):
    """Assign a PBR material based on part name substring matching."""
    material_key = "paint_olive"  # Default
    for substring, mat_key in PART_MATERIAL_MAP:
        if substring in part_name.lower():
            material_key = mat_key
            break

    preset = MATERIALS[material_key]
    mat = create_pbr_material(f"mat_{part_name}", preset)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return material_key


# ─── STL Import ──────────────────────────────────────────────────────────────

def import_stl_files(stl_dir, part_filter="full_assembly"):
    """Import STL files and apply materials."""
    stl_dir = Path(stl_dir)
    imported = []

    if part_filter == "all":
        stl_files = sorted(stl_dir.glob("*.stl"))
    else:
        parts = [p.strip() for p in part_filter.split(",")]
        stl_files = []
        for part in parts:
            stl_file = stl_dir / f"{part}.stl"
            if stl_file.exists():
                stl_files.append(stl_file)

    for stl_file in stl_files:
        bpy.ops.import_mesh.stl(filepath=str(stl_file))
        obj = bpy.context.selected_objects[-1]
        obj.name = stl_file.stem

        # Scale mm → m (Blender uses meters)
        obj.scale = (0.001, 0.001, 0.001)
        bpy.ops.object.transform_apply(scale=True)

        # Smooth shading
        bpy.ops.object.shade_smooth()

        # Auto-smooth normals
        if hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(30)

        # Apply material
        mat_key = assign_material(obj, stl_file.stem)
        imported.append((obj, mat_key))
        print(f"[render_pro] Imported: {stl_file.stem} -> {mat_key}")

    return imported


# ─── Camera Setup ────────────────────────────────────────────────────────────

def setup_camera(objects):
    """Position camera with 85mm lens, DoF, auto-framed on model."""
    # Calculate combined bounding box
    min_corner = Vector((float("inf"),) * 3)
    max_corner = Vector((float("-inf"),) * 3)

    for obj, _ in objects:
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            min_corner = Vector((min(a, b) for a, b in zip(min_corner, world_corner)))
            max_corner = Vector((max(a, b) for a, b in zip(max_corner, world_corner)))

    center = (min_corner + max_corner) / 2
    size = max_corner - min_corner
    max_dim = max(size)

    # Camera distance for 85mm lens to frame the model
    # FOV = 2 * atan(sensor_width / (2 * focal_length))
    sensor_width = 36  # mm (full frame)
    fov = 2 * math.atan(sensor_width / (2 * FOCAL_LENGTH_MM))
    distance = (max_dim / 2) / math.tan(fov / 2) * 1.4  # 1.4x margin

    # 3/4 view position
    azimuth = math.radians(CAMERA_AZIMUTH_DEG)
    elevation = math.radians(CAMERA_ELEVATION_DEG)
    cam_x = center.x + distance * math.cos(elevation) * math.sin(azimuth)
    cam_y = center.y - distance * math.cos(elevation) * math.cos(azimuth)
    cam_z = center.z + distance * math.sin(elevation)

    # Create camera
    bpy.ops.object.camera_add(location=(cam_x, cam_y, cam_z))
    camera = bpy.context.object
    camera.name = "ProCamera"
    bpy.context.scene.camera = camera

    # Lens settings
    camera.data.lens = FOCAL_LENGTH_MM
    camera.data.sensor_width = sensor_width

    # Depth of Field
    camera.data.dof.use_dof = True
    camera.data.dof.aperture_fstop = F_STOP

    # Create empty at model center for focus target
    bpy.ops.object.empty_add(location=center)
    focus_target = bpy.context.object
    focus_target.name = "FocusTarget"
    camera.data.dof.focus_object = focus_target

    # Point camera at center
    direction = center - Vector((cam_x, cam_y, cam_z))
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    print(f"[render_pro] Camera: {FOCAL_LENGTH_MM}mm, f/{F_STOP}, distance={distance:.3f}m")
    return camera


# ─── Ground Plane ────────────────────────────────────────────────────────────

def add_ground_plane(objects):
    """Add a subtle ground plane for shadow catching."""
    # Find lowest point
    min_z = float("inf")
    max_dim = 0
    for obj, _ in objects:
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            min_z = min(min_z, world_corner.z)

    # Calculate model extent for plane size
    for obj, _ in objects:
        size = obj.dimensions
        max_dim = max(max_dim, max(size))

    bpy.ops.mesh.primitive_plane_add(size=max_dim * 4, location=(0, 0, min_z))
    plane = bpy.context.object
    plane.name = "GroundPlane"

    # Shadow catcher material
    mat = bpy.data.materials.new("GroundMat")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.12, 0.12, 0.14, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Metallic"].default_value = 0.0
    plane.data.materials.append(mat)

    return plane


# ─── Output Settings ─────────────────────────────────────────────────────────

def setup_output(output_path, resolution, transparent=False):
    """Configure render output."""
    scene = bpy.context.scene
    w, h = [int(x) for x in resolution.split("x")]
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(Path(output_path).resolve())
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "16"
    scene.render.film_transparent = transparent
    print(f"[render_pro] Output: {output_path} ({w}x{h})")


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    args = parse_args()
    print(f"\n{'='*60}")
    print(f"  ROBOT4KID Pro Renderer (Blender Cycles)")
    print(f"{'='*60}\n")

    # 1. Clear scene
    clear_scene()

    # 2. Setup render engine
    setup_render_engine(args.samples)

    # 3. Setup HDRI / studio lighting
    setup_hdri(args.hdri)

    # 4. Import STL files and apply PBR materials
    objects = import_stl_files(args.stl_dir, args.parts)
    if not objects:
        print("[render_pro] ERROR: No STL files found!")
        sys.exit(1)

    # 5. Add ground plane
    add_ground_plane(objects)

    # 6. Setup camera with DoF
    camera = setup_camera(objects)

    # 7. Configure output
    setup_output(args.output, args.resolution, args.transparent)

    # 8. Render
    print(f"\n[render_pro] Rendering {args.samples} samples...")
    bpy.ops.render.render(write_still=True)
    print(f"[render_pro] Done! Output: {args.output}")


if __name__ == "__main__":
    main()
