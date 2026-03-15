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
    job_dir = config.JOBS_DIR / job_id / "output"
    if not job_dir.exists():
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' not found")

    # Find all STL files
    stl_files = sorted(job_dir.glob("*.stl"))
    parts_data = []
    for stl in stl_files:
        part_id = stl.stem
        parts_data.append({
            "id": part_id,
            "url": f"/api/v1/jobs/{job_id}/stl/{part_id}",
        })

    # Read feedback for colors
    feedback_path = config.JOBS_DIR / job_id / "feedback.json"
    if feedback_path.exists():
        feedback = json.loads(feedback_path.read_text())
        for part_info in parts_data:
            for rr in feedback.get("render_results", []):
                if rr["part_id"] == part_info["id"]:
                    part_info["dimensions"] = rr.get("dimensions_mm", [0, 0, 0])

    html = _generate_viewer_html(job_id, parts_data)
    return HTMLResponse(content=html)


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


def _generate_viewer_html(job_id: str, parts: list[dict]) -> str:
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

        // Track bounding boxes for layout
        const meshes = [];
        let offsetX = 0;
        const gap = 20; // mm gap between parts

        parts.forEach((part, index) => {{
            loader.load(part.url, (geometry) => {{
                geometry.computeVertexNormals();
                geometry.center(); // Center geometry at origin

                const material = new THREE.MeshPhongMaterial({{
                    color: colors[index % colors.length],
                    specular: 0x222222,
                    shininess: 40,
                }});
                const mesh = new THREE.Mesh(geometry, material);
                mesh.userData.partId = part.id;
                mesh.userData.index = index;
                meshes.push(mesh);
                scene.add(mesh);

                loaded++;
                document.getElementById('part-count').textContent = loaded + ' / ' + parts.length + ' parts loaded';

                if (loaded === parts.length) {{
                    // Layout parts in a row (sorted by original index)
                    meshes.sort((a, b) => a.userData.index - b.userData.index);
                    let curX = 0;
                    meshes.forEach(m => {{
                        const box = new THREE.Box3().setFromObject(m);
                        const size = box.getSize(new THREE.Vector3());
                        m.position.x = curX + size.x / 2;
                        // Place on ground plane
                        const newBox = new THREE.Box3().setFromObject(m);
                        m.position.y -= newBox.min.y;
                        curX += size.x + gap;
                    }});

                    // Auto-fit camera
                    const box = new THREE.Box3();
                    scene.traverse(c => {{ if (c.isMesh) box.expandByObject(c); }});
                    const center = box.getCenter(new THREE.Vector3());
                    const size = box.getSize(new THREE.Vector3());
                    const maxDim = Math.max(size.x, size.y, size.z);
                    camera.position.set(center.x + maxDim * 0.8, center.y + maxDim * 0.6, center.z + maxDim * 0.8);
                    controls.target.copy(center);
                    controls.update();
                }}
            }});
        }});

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
