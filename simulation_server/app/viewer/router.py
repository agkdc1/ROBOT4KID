"""3D web viewer endpoints."""

import json
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from simulation_server.app import config

router = APIRouter()


@router.get("/{job_id}", response_class=HTMLResponse)
async def viewer_page(job_id: str):
    """Serve the 3D viewer page for a specific job."""
    job_dir = config.JOBS_DIR / job_id
    output_dir = job_dir / "output"
    if not output_dir.exists():
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' not found")

    # Find all STL files
    stl_files = sorted(output_dir.glob("*.stl"))
    parts_data = []
    for stl in stl_files:
        part_id = stl.stem
        is_electronic = part_id.startswith("elec_")
        parts_data.append({
            "id": part_id,
            "url": f"/api/v1/jobs/{job_id}/stl/{part_id}",
            "is_electronic": is_electronic,
        })

    # Read robot_spec.json for assembly positions
    spec_path = job_dir / "robot_spec.json"
    assembly_data = None
    if spec_path.exists():
        try:
            spec = json.loads(spec_path.read_text())
            assembly_data = _build_assembly_data(spec)
        except Exception:
            pass

    # Enrich parts_data with assembly positions
    if assembly_data:
        for part_info in parts_data:
            pid = part_info["id"]
            if pid in assembly_data:
                part_info["assembly"] = assembly_data[pid]

    # Read feedback for colors/dimensions
    feedback_path = job_dir / "feedback.json"
    if feedback_path.exists():
        feedback = json.loads(feedback_path.read_text())
        for part_info in parts_data:
            for rr in feedback.get("render_results", []):
                if rr["part_id"] == part_info["id"]:
                    part_info["dimensions"] = rr.get("dimensions_mm", [0, 0, 0])

    html = _generate_viewer_html(job_id, parts_data, has_assembly=assembly_data is not None)
    return HTMLResponse(content=html)


def _build_assembly_data(spec: dict) -> dict:
    """Build a mapping of part_id -> {position, rotation, color} from a RobotSpec."""
    assembly = {}
    parts_by_id = {p["id"]: p for p in spec.get("parts", [])}

    # Build joint tree: child -> (parent, origin_xyz, origin_rpy)
    joint_map = {}
    for j in spec.get("joints", []):
        joint_map[j["child_part"]] = {
            "parent": j["parent_part"],
            "xyz": j.get("origin_xyz", [0, 0, 0]),
            "rpy": j.get("origin_rpy", [0, 0, 0]),
        }

    # Compute absolute positions by walking joint tree
    def get_absolute_pos(part_id: str, visited=None) -> list[float]:
        if visited is None:
            visited = set()
        if part_id in visited:
            return [0, 0, 0]
        visited.add(part_id)
        if part_id not in joint_map:
            return [0, 0, 0]  # Root part
        j = joint_map[part_id]
        parent_pos = get_absolute_pos(j["parent"], visited)
        return [parent_pos[i] + j["xyz"][i] for i in range(3)]

    for part in spec.get("parts", []):
        pos = get_absolute_pos(part["id"])
        assembly[part["id"]] = {
            "position": pos,
            "rotation": [0, 0, 0],
            "color": part.get("color", "#4a7c59"),
        }

    # Electronics: position = host part position + mount offset
    for elec in spec.get("electronics", []):
        host_pos = get_absolute_pos(elec["host_part"])
        mount = elec.get("mount_position_mm", [0, 0, 0])
        abs_pos = [host_pos[i] + mount[i] for i in range(3)]

        from shared.electronics_catalog import lookup
        info = lookup(elec["type"])
        color = info.color_hex if info else "#4caf50"

        assembly[f"elec_{elec['id']}"] = {
            "position": abs_pos,
            "rotation": list(elec.get("mount_orientation_rpy", [0, 0, 0])),
            "color": color,
            "is_electronic": True,
        }

    return assembly


@router.get("/{job_id}/parts")
async def viewer_parts(job_id: str):
    """Get list of parts with STL URLs for the viewer."""
    job_dir = config.JOBS_DIR / job_id / "output"
    if not job_dir.exists():
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' not found")

    stl_files = sorted(job_dir.glob("*.stl"))
    return [
        {
            "id": stl.stem,
            "url": f"/api/v1/jobs/{job_id}/stl/{stl.stem}",
            "size_bytes": stl.stat().st_size,
        }
        for stl in stl_files
    ]


def _generate_viewer_html(job_id: str, parts: list[dict], has_assembly: bool = False) -> str:
    """Generate a self-contained Three.js viewer HTML page."""
    parts_json = json.dumps(parts)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NL2Bot Viewer — Job {job_id}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ overflow: hidden; background: #1a1a2e; font-family: 'Segoe UI', sans-serif; }}
        #info {{
            position: absolute; top: 10px; left: 10px; z-index: 10;
            color: #e0e0e0; background: rgba(0,0,0,0.7); padding: 12px 16px;
            border-radius: 8px; font-size: 13px;
        }}
        #info h3 {{ margin-bottom: 6px; color: #4fc3f7; }}
        #controls {{
            position: absolute; bottom: 10px; left: 10px; z-index: 10;
            color: #ccc; background: rgba(0,0,0,0.7); padding: 10px 14px;
            border-radius: 8px; font-size: 12px;
        }}
        #part-info {{
            position: absolute; top: 10px; right: 10px; z-index: 10;
            color: #e0e0e0; background: rgba(0,0,0,0.7); padding: 12px 16px;
            border-radius: 8px; font-size: 13px; min-width: 200px; display: none;
        }}
        canvas {{ display: block; }}
    </style>
</head>
<body>
    <div id="info">
        <h3>NL2Bot 3D Viewer</h3>
        <div>Job: {job_id}</div>
        <div id="part-count">Loading parts...</div>
    </div>
    <div id="controls">
        Orbit: Left-click drag | Zoom: Scroll | Pan: Right-click drag
        {'| <button id="toggle-view" onclick="toggleView()" style="background:#4fc3f7;color:#000;border:none;padding:4px 12px;cursor:pointer;border-radius:3px;font-weight:bold;">ASSEMBLED</button> <button id="toggle-elec" onclick="toggleElectronics()" style="background:#81c784;color:#000;border:none;padding:4px 12px;cursor:pointer;border-radius:3px;font-weight:bold;">ELECTRONICS: ON</button>' if has_assembly else ''}
    </div>
    <div id="part-info">
        <h4 id="pi-name"></h4>
        <div id="pi-details"></div>
    </div>

    <script type="importmap">
    {{
        "imports": {{
            "three": "https://cdn.jsdelivr.net/npm/three@0.162.0/build/three.module.js",
            "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.162.0/examples/jsm/"
        }}
    }}
    </script>
    <script type="module">
        import * as THREE from 'three';
        import {{ OrbitControls }} from 'three/addons/controls/OrbitControls.js';
        import {{ STLLoader }} from 'three/addons/loaders/STLLoader.js';

        const parts = {parts_json};
        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0x1a1a2e);

        const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 10000);
        camera.position.set(300, 200, 300);

        const renderer = new THREE.WebGLRenderer({{ antialias: true }});
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(window.devicePixelRatio);
        document.body.appendChild(renderer.domElement);

        const controls = new OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.05;

        // Lighting
        const ambientLight = new THREE.AmbientLight(0x404040, 2);
        scene.add(ambientLight);
        const dirLight = new THREE.DirectionalLight(0xffffff, 3);
        dirLight.position.set(200, 300, 200);
        scene.add(dirLight);
        const fillLight = new THREE.DirectionalLight(0x4fc3f7, 1);
        fillLight.position.set(-200, 100, -200);
        scene.add(fillLight);

        // Grid
        const grid = new THREE.GridHelper(500, 50, 0x333355, 0x222244);
        scene.add(grid);

        // Load STL parts
        const loader = new STLLoader();
        const colors = [0x4fc3f7, 0x81c784, 0xffb74d, 0xba68c8, 0xe57373, 0x4db6ac, 0xfff176];
        let loaded = 0;

        // State
        const meshes = [];
        let assembledMode = {'true' if has_assembly else 'false'};
        let showElectronics = true;
        const hasAssembly = {'true' if has_assembly else 'false'};

        // Color map for electronics categories
        const elecColors = {{
            pcb: 0x1565c0, motor: 0x757575, battery: 0xe65100,
            sensor: 0x4a148c, connector: 0xff6f00, peripheral: 0x37474f,
        }};

        parts.forEach((part, index) => {{
            loader.load(part.url, (geometry) => {{
                geometry.computeVertexNormals();
                geometry.center();

                const isElec = part.is_electronic || false;
                let color = colors[index % colors.length];
                let opacity = 1.0;

                // Use assembly color if available
                if (part.assembly && part.assembly.color) {{
                    const c = part.assembly.color.replace('#', '');
                    color = parseInt(c, 16);
                }}
                if (isElec) {{
                    opacity = 0.85;
                }}

                const material = new THREE.MeshPhongMaterial({{
                    color: color,
                    specular: 0x222222,
                    shininess: isElec ? 60 : 40,
                    transparent: isElec,
                    opacity: opacity,
                }});
                const mesh = new THREE.Mesh(geometry, material);
                mesh.userData.partId = part.id;
                mesh.userData.index = index;
                mesh.userData.isElectronic = isElec;
                mesh.userData.assembly = part.assembly || null;
                meshes.push(mesh);
                scene.add(mesh);

                loaded++;
                const elecCount = parts.filter(p => p.is_electronic).length;
                const printedCount = parts.length - elecCount;
                document.getElementById('part-count').textContent =
                    loaded + '/' + parts.length + ' loaded (' + printedCount + ' printed, ' + elecCount + ' electronics)';

                if (loaded === parts.length) {{
                    layoutParts();
                }}
            }});
        }});

        function layoutParts() {{
            meshes.sort((a, b) => a.userData.index - b.userData.index);

            if (assembledMode && hasAssembly) {{
                // Assembled view: use assembly positions
                meshes.forEach(m => {{
                    const asm = m.userData.assembly;
                    if (asm) {{
                        // OpenSCAD uses mm, Three.js uses same units here
                        m.position.set(asm.position[0], asm.position[2], asm.position[1]);
                    }} else {{
                        m.position.set(0, 0, 0);
                    }}
                    m.visible = m.userData.isElectronic ? showElectronics : true;
                }});
            }} else {{
                // Exploded view: lay out in a row
                const gap = 20;
                const printedMeshes = meshes.filter(m => !m.userData.isElectronic);
                const elecMeshes = meshes.filter(m => m.userData.isElectronic);

                let curX = 0;
                printedMeshes.forEach(m => {{
                    const box = new THREE.Box3().setFromObject(m);
                    const size = box.getSize(new THREE.Vector3());
                    m.position.set(curX + size.x / 2, 0, 0);
                    const newBox = new THREE.Box3().setFromObject(m);
                    m.position.y -= newBox.min.y;
                    curX += size.x + gap;
                    m.visible = true;
                }});

                // Electronics in a second row below
                let elecX = 0;
                elecMeshes.forEach(m => {{
                    const box = new THREE.Box3().setFromObject(m);
                    const size = box.getSize(new THREE.Vector3());
                    m.position.set(elecX + size.x / 2, 0, -80);
                    const newBox = new THREE.Box3().setFromObject(m);
                    m.position.y -= newBox.min.y;
                    elecX += size.x + gap;
                    m.visible = showElectronics;
                }});
            }}

            // Auto-fit camera
            const box = new THREE.Box3();
            scene.traverse(c => {{ if (c.isMesh && c.visible) box.expandByObject(c); }});
            if (!box.isEmpty()) {{
                const center = box.getCenter(new THREE.Vector3());
                const size = box.getSize(new THREE.Vector3());
                const maxDim = Math.max(size.x, size.y, size.z);
                camera.position.set(center.x + maxDim * 0.8, center.y + maxDim * 0.6, center.z + maxDim * 0.8);
                controls.target.copy(center);
                controls.update();
            }}
        }}

        // Global toggle functions
        window.toggleView = function() {{
            assembledMode = !assembledMode;
            const btn = document.getElementById('toggle-view');
            if (btn) btn.textContent = assembledMode ? 'ASSEMBLED' : 'EXPLODED';
            layoutParts();
        }};

        window.toggleElectronics = function() {{
            showElectronics = !showElectronics;
            const btn = document.getElementById('toggle-elec');
            if (btn) btn.textContent = 'ELECTRONICS: ' + (showElectronics ? 'ON' : 'OFF');
            meshes.forEach(m => {{
                if (m.userData.isElectronic) m.visible = showElectronics;
            }});
        }};

        // Click to highlight part
        const raycaster = new THREE.Raycaster();
        const mouse = new THREE.Vector2();
        let selectedMesh = null;

        renderer.domElement.addEventListener('click', (event) => {{
            mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
            mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
            raycaster.setFromCamera(mouse, camera);
            const intersects = raycaster.intersectObjects(scene.children.filter(c => c.isMesh));

            // Reset previous selection
            if (selectedMesh) {{
                selectedMesh.material.emissive.setHex(0x000000);
            }}

            const partInfo = document.getElementById('part-info');
            if (intersects.length > 0) {{
                selectedMesh = intersects[0].object;
                selectedMesh.material.emissive.setHex(0x333333);
                document.getElementById('pi-name').textContent = selectedMesh.userData.partId || 'Unknown';
                const box = new THREE.Box3().setFromObject(selectedMesh);
                const sz = box.getSize(new THREE.Vector3());
                document.getElementById('pi-details').textContent =
                    sz.x.toFixed(1) + ' x ' + sz.y.toFixed(1) + ' x ' + sz.z.toFixed(1) + ' mm';
                partInfo.style.display = 'block';
            }} else {{
                selectedMesh = null;
                partInfo.style.display = 'none';
            }}
        }});

        window.addEventListener('resize', () => {{
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        }});

        function animate() {{
            requestAnimationFrame(animate);
            controls.update();
            renderer.render(scene, camera);
        }}
        animate();
    </script>
</body>
</html>"""
