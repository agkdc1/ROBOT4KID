#!/usr/bin/env python3
"""Run Grand Audit (Phase 3) with Deep Think for all 3 projects.

Usage:
    python run_grand_audit.py [--project tank|train|console|all]

Requires: GEMINI_API_KEY or GCP_PROJECT_ID in .env
"""

import asyncio
import json
import logging
import os
import sys
from pathlib import Path
from datetime import datetime, timezone

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT))

# Load .env
env_path = PROJECT_ROOT / ".env"
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

from planning_server.app.pipeline.grand_audit import (
    run_grand_audit,
    run_meta_audit,
    set_pipeline_state,
    get_pipeline_state,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("grand_audit_runner")

DATA_DIR = PROJECT_ROOT / "planning_server" / "data" / "projects"


# ─── Project Definitions ────────────────────────────────────────────

PROJECTS = {
    "tank": {
        "project_id": "15",
        "model_type": "tank",
        "model_name": "M1A1 Abrams",
        "scad_dirs": [
            PROJECT_ROOT / "cad" / "chassis",
            PROJECT_ROOT / "cad" / "turret",
            PROJECT_ROOT / "cad" / "libs",
        ],
        "scad_files": [
            "hull.scad", "hull_v2.scad",
            "track_assembly.scad", "track_assembly_v2.scad",
            "electronics_bay.scad", "modular_inserts.scad",
            "turret_body.scad", "turret_v2.scad",
            "gun_barrel.scad",
        ],
        "validation_dir": DATA_DIR / "15",
    },
    "train": {
        "project_id": "16",
        "model_type": "train",
        "model_name": "Shinkansen N700",
        "scad_dirs": [
            PROJECT_ROOT / "cad" / "train",
            PROJECT_ROOT / "cad" / "libs",
        ],
        "scad_files": [
            "locomotive.scad",
            "motor_mount.scad", "battery_bay.scad", "camera_mount.scad",
            "train_assembly.scad",
            "plarail_shell_v2.scad", "plarail_chassis_v2.scad",
            "plarail_assembly_v2.scad", "plarail_track.scad",
        ],
        "validation_dir": DATA_DIR / "16",
    },
    "console": {
        "project_id": "17",
        "model_type": "console",
        "model_name": "Universal Command Console",
        "scad_dirs": [
            PROJECT_ROOT / "project-cradle" / "cad",
            PROJECT_ROOT / "cad" / "cockpit",
            PROJECT_ROOT / "cad" / "libs",
        ],
        "scad_files": [
            "console.scad",
            "console_cradle.scad", "train_console.scad",
        ],
        "validation_dir": DATA_DIR / "17",
    },
}


def _collect_scad_sources(project: dict) -> dict[str, str]:
    """Collect SCAD source code from project's directories."""
    sources = {}
    target_files = set(project["scad_files"])

    for scad_dir in project["scad_dirs"]:
        if not scad_dir.exists():
            logger.warning(f"SCAD dir not found: {scad_dir}")
            continue
        for scad_file in sorted(scad_dir.glob("*.scad")):
            if scad_file.name in target_files or scad_dir.name == "libs":
                content = scad_file.read_text(encoding="utf-8", errors="replace")
                sources[scad_file.name] = content
                logger.info(f"  Loaded {scad_file.name} ({len(content)} chars)")

    return sources


def _collect_stage_results(project: dict) -> dict[str, any]:
    """Collect existing validation/audit results as proxy stage results."""
    results = {}
    val_dir = project["validation_dir"]

    if not val_dir.exists():
        logger.warning(f"No validation dir: {val_dir}")
        return {"status": "no_prior_validation"}

    for json_file in sorted(val_dir.glob("*.json")):
        if json_file.name == "pipeline_state.json":
            continue
        try:
            data = json.loads(json_file.read_text(encoding="utf-8"))
            results[json_file.stem] = data
            logger.info(f"  Loaded {json_file.name}")
        except (json.JSONDecodeError, Exception) as e:
            logger.warning(f"  Failed to load {json_file.name}: {e}")

    # Also check project-cradle renders for console
    if project["model_type"] == "console":
        cradle_dir = PROJECT_ROOT / "project-cradle" / "renders"
        for txt_file in sorted(cradle_dir.glob("*.txt")):
            content = txt_file.read_text(encoding="utf-8", errors="replace")
            results[f"cradle_{txt_file.stem}"] = {"raw_text": content}
            logger.info(f"  Loaded cradle render: {txt_file.name}")

    if not results:
        return {"status": "no_prior_validation"}

    return results


def _build_assembly_manual(project: dict) -> str:
    """Build a summary assembly manual from README / hardware specs."""
    manual_parts = []

    # Check for project-specific README
    if project["model_type"] == "console":
        readme = PROJECT_ROOT / "project-cradle" / "README.md"
        if readme.exists():
            manual_parts.append(readme.read_text(encoding="utf-8"))

    # Hardware specs excerpt
    hw_path = PROJECT_ROOT / "config" / "hardware_specs.yaml"
    if hw_path.exists():
        import yaml
        hw = yaml.safe_load(hw_path.read_text(encoding="utf-8"))
        model_type = project["model_type"]
        if model_type in hw:
            manual_parts.append(f"## Hardware Specs ({model_type})\n```yaml\n{json.dumps(hw[model_type], indent=2)}\n```")
        if "components" in hw:
            manual_parts.append(f"## Components\n```yaml\n{json.dumps(hw['components'], indent=2)}\n```")

    return "\n\n".join(manual_parts) if manual_parts else None


def _ensure_project_dir(project: dict) -> Path:
    """Ensure project data directory exists."""
    val_dir = project["validation_dir"]
    val_dir.mkdir(parents=True, exist_ok=True)
    return val_dir


def _ensure_db_project(project_id: str, name: str, description: str, owner_id: int = 1) -> None:
    """Register project in SQLite DB if not already present. Default owner = admin (id=1)."""
    import sqlite3
    db_path = PROJECT_ROOT / "planning_server" / "data" / "db.sqlite3"
    if not db_path.exists():
        logger.warning(f"DB not found: {db_path}")
        return

    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.execute("SELECT id FROM projects WHERE id = ?", (int(project_id),))
    if not cur.fetchone():
        now = datetime.now(timezone.utc).isoformat()
        cur.execute(
            "INSERT INTO projects (id, name, description, owner_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'active', ?, ?)",
            (int(project_id), name, description, owner_id, now, now),
        )
        conn.commit()
        logger.info(f"Registered project {project_id}: {name} (owner_id={owner_id})")
    else:
        logger.info(f"Project {project_id} already exists in DB")
    conn.close()


async def run_audit_for_project(project_key: str) -> dict:
    """Run Grand Audit for a single project."""
    project = PROJECTS[project_key]
    project_dir = _ensure_project_dir(project)

    logger.info(f"\n{'='*70}")
    logger.info(f"GRAND AUDIT: {project['model_name']} (project {project['project_id']})")
    logger.info(f"{'='*70}")

    # Ensure DB entry
    _ensure_db_project(
        project["project_id"],
        project["model_name"],
        f"Grand Audit target — {project['model_type']}",
    )

    # Update pipeline state
    set_pipeline_state(project_dir, "ultra_grand_audit", "in_progress")

    # Collect inputs
    logger.info("Collecting SCAD sources...")
    scad_sources = _collect_scad_sources(project)
    if not scad_sources:
        logger.error(f"No SCAD sources found for {project_key}!")
        set_pipeline_state(project_dir, "ultra_grand_audit", "failed", notes="No SCAD sources")
        return {"error": "No SCAD sources"}

    logger.info(f"Collected {len(scad_sources)} SCAD files")

    logger.info("Collecting stage results...")
    stage_results = _collect_stage_results(project)

    logger.info("Building assembly manual...")
    assembly_manual = _build_assembly_manual(project)

    # Run Grand Audit with Deep Think
    logger.info(f"Submitting to Gemini Ultra (Deep Think)...")
    try:
        result = await run_grand_audit(
            stage_results=stage_results,
            scad_sources=scad_sources,
            model_type=project["model_type"],
            model_name=project["model_name"],
            assembly_manual=assembly_manual,
        )
    except Exception as e:
        logger.error(f"Grand Audit FAILED: {e}")
        set_pipeline_state(project_dir, "ultra_grand_audit", "failed", notes=str(e))
        return {"error": str(e)}

    # Save result
    verdict = result.get("verdict", "UNKNOWN")
    output_path = project_dir / "grand_audit_result.json"
    result["_timestamp"] = datetime.now(timezone.utc).isoformat()
    result["_project"] = project_key
    output_path.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    logger.info(f"Saved: {output_path}")

    # Update pipeline state
    score = sum([
        result.get("core_gimmick_ok", False),
        result.get("manual_realism_ok", False),
        result.get("structural_ok", False),
        result.get("kinematics_ok", False),
        result.get("thermal_ok", False),
    ])
    set_pipeline_state(
        project_dir, "ultra_grand_audit",
        "passed" if verdict == "PASS" else "failed",
        score=score * 2,  # Scale to 10
        notes=f"{verdict} via {result.get('_model_used', 'unknown')}",
    )

    # Print summary
    logger.info(f"\n{'─'*50}")
    logger.info(f"VERDICT: {verdict}")
    logger.info(f"  Core Gimmick:    {'✓' if result.get('core_gimmick_ok') else '✗'}")
    logger.info(f"  Manual Realism:  {'✓' if result.get('manual_realism_ok') else '✗'}")
    logger.info(f"  Structural:      {'✓' if result.get('structural_ok') else '✗'}")
    logger.info(f"  Kinematics:      {'✓' if result.get('kinematics_ok') else '✗'}")
    logger.info(f"  Thermal:         {'✓' if result.get('thermal_ok') else '✗'}")
    logger.info(f"  Model Used:      {result.get('_model_used', 'unknown')}")

    issues = result.get("issues", [])
    if issues:
        logger.info(f"\n  Issues ({len(issues)}):")
        for issue in issues:
            sev = issue.get("severity", "?")
            desc = issue.get("description", "")[:100]
            logger.info(f"    [{sev}] {desc}")

    prompt_updates = result.get("prompt_updates", [])
    if prompt_updates:
        logger.info(f"\n  Meta-Corrections ({len(prompt_updates)}):")
        for pu in prompt_updates:
            logger.info(f"    Stage {pu.get('stage')}: {pu.get('addition', '')[:80]}")

    return result


async def main():
    import argparse
    parser = argparse.ArgumentParser(description="Run Grand Audit with Deep Think")
    parser.add_argument("--project", choices=["tank", "train", "console", "all"], default="all")
    args = parser.parse_args()

    targets = list(PROJECTS.keys()) if args.project == "all" else [args.project]

    results = {}
    for target in targets:
        results[target] = await run_audit_for_project(target)

    # Final summary
    logger.info(f"\n{'='*70}")
    logger.info("GRAND AUDIT SUMMARY")
    logger.info(f"{'='*70}")
    for name, result in results.items():
        verdict = result.get("verdict", result.get("error", "ERROR"))
        model = result.get("_model_used", "N/A")
        logger.info(f"  {name:12s} → {verdict:6s} (via {model})")

    return results


if __name__ == "__main__":
    asyncio.run(main())
