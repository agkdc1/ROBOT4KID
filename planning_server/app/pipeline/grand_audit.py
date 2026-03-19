"""Grand Audit module — Phase 1 (Meta-Audit) and Phase 3 (Grand Audit).

ALL audit calls use Vertex AI Batch Prediction as the primary path:
- No output truncation (results written to GCS as full JSONL)
- 50% cost discount vs real-time inference
- Automatic retries with 24hr SLA
- Deep Think (thinking_level=HIGH) supported in batch JSONL

Falls back to real-time cascade only if batch is unavailable (no GCS bucket,
no GCP project, or batch submission fails).

Architecture:
    Batch (primary):  prompt → GCS JSONL → batch job → poll → GCS output → parse
    Realtime (fallback): prompt → generate_with_tool() → parse
"""

import json
import logging
import os
from pathlib import Path
from typing import Any

from planning_server.app.pipeline.llm import Provider, generate_with_tool

logger = logging.getLogger(__name__)

# ─── Model Configuration ────────────────────────────────────────────

ULTRA_MODEL = "gemini-3.1-pro-preview"
ULTRA_THINKING_LEVEL = "HIGH"

# Batch models (Pro only for Grand Audit)
BATCH_MODEL = "gemini-3.1-pro-preview"
BATCH_FALLBACK = "gemini-3-pro-preview"

# Realtime fallback cascade: (model_id, thinking_level, force_aistudio)
REALTIME_CASCADE = [
    ("gemini-3.1-pro-preview", "HIGH", False),
    ("gemini-3-pro-preview", "HIGH", False),
    ("gemini-3.1-pro-preview", "HIGH", True),
    ("gemini-3-pro-preview", "HIGH", True),
]

# Use batch by default if GCP is configured
USE_BATCH = os.getenv("GRAND_AUDIT_USE_BATCH", "true").lower() in ("true", "1", "yes")


# ─── Tool Schemas ───────────────────────────────────────────────────

META_AUDIT_TOOL = {
    "name": "meta_audit",
    "description": "Phase 1 Meta-Audit: evaluates the Master Document before design begins.",
    "input_schema": {
        "type": "object",
        "properties": {
            "approval": {
                "type": "string",
                "enum": ["APPROVED", "REVISE"],
                "description": "Whether the Master Document is approved or needs revision.",
            },
            "proportions_ok": {"type": "boolean", "description": "Size proportions physically coherent?"},
            "circuit_ok": {"type": "boolean", "description": "Electronic circuit complete (V, A, wiring)?"},
            "philosophy_ok": {"type": "boolean", "description": "Follows Universal Modular Insert Standard?"},
            "modularity_ok": {"type": "boolean", "description": "Screw types correct? Inserts accessible?"},
            "issues": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "category": {"type": "string"},
                        "severity": {"type": "string", "enum": ["critical", "major", "minor"]},
                        "description": {"type": "string"},
                        "fix": {"type": "string"},
                    },
                    "required": ["category", "severity", "description"],
                },
            },
            "positive_notes": {"type": "array", "items": {"type": "string"}},
        },
        "required": ["approval", "proportions_ok", "circuit_ok", "philosophy_ok", "modularity_ok"],
    },
}

GRAND_AUDIT_TOOL = {
    "name": "grand_audit",
    "description": "Phase 3 Grand Audit: final sign-off by Chief Inspector.",
    "input_schema": {
        "type": "object",
        "properties": {
            "verdict": {
                "type": "string",
                "enum": ["PASS", "FAIL"],
                "description": "Final verdict.",
            },
            "core_gimmick_ok": {"type": "boolean", "description": "Primary play feature functions mechanically?"},
            "manual_realism_ok": {"type": "boolean", "description": "Human can assemble with screwdriver?"},
            "structural_ok": {"type": "boolean", "description": "Holes open, walls sealed, manifold?"},
            "kinematics_ok": {"type": "boolean", "description": "Motors function, CoG stable?"},
            "thermal_ok": {"type": "boolean", "description": "Ventilation adequate, no over-discharge risk?"},
            "issues": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion": {"type": "string"},
                        "severity": {"type": "string", "enum": ["critical", "major", "minor"]},
                        "description": {"type": "string"},
                        "fix": {"type": "string"},
                        "missed_by_stage": {
                            "type": "integer",
                            "description": "Which stage (1-4) should have caught this? 0 if new.",
                        },
                    },
                    "required": ["criterion", "severity", "description"],
                },
            },
            "prompt_updates": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stage": {"type": "integer", "description": "Stage 1-4 to update."},
                        "addition": {"type": "string", "description": "New check to add to that stage's prompt."},
                        "reason": {"type": "string", "description": "Why this was missed."},
                    },
                },
                "description": "Meta-correction: updates to Stage 1-4 prompts if Ultra found gaps.",
            },
            "delta_feedback": {
                "type": "object",
                "properties": {
                    "files_to_fix": {"type": "array", "items": {"type": "string"}},
                    "resubmit_scope": {"type": "string", "description": "What to resubmit for delta audit."},
                },
                "description": "Isolation commands for targeted re-audit.",
            },
            "positive_notes": {"type": "array", "items": {"type": "string"}},
        },
        "required": ["verdict", "core_gimmick_ok", "manual_realism_ok", "structural_ok", "kinematics_ok", "thermal_ok"],
    },
}


# ─── Unified Audit Caller ───────────────────────────────────────────

async def _call_audit(
    prompt: str,
    system: str,
    tool: dict,
    tool_name: str,
) -> tuple[str, dict[str, Any]]:
    """Route audit call: batch (primary) → realtime (fallback).

    Batch path: no truncation, 50% cheaper, GCS-backed.
    Realtime path: immediate response, used when batch unavailable.
    """
    if USE_BATCH:
        try:
            return await _call_via_batch(prompt, system, tool)
        except Exception as e:
            logger.warning(f"[AUDIT] Batch failed ({e}), falling back to realtime cascade")

    return await _call_via_realtime(prompt, system, tool, tool_name)


async def _call_via_batch(
    prompt: str,
    system: str,
    tool: dict,
) -> tuple[str, dict[str, Any]]:
    """Submit audit via Vertex AI Batch Prediction. No output truncation."""
    from planning_server.app.pipeline.batch_audit import run_batch_grand_audit

    model_used, result = await run_batch_grand_audit(
        prompt=prompt,
        system=system,
        tool_schema=tool.get("input_schema", {}),
        model=BATCH_MODEL,
        thinking_level=ULTRA_THINKING_LEVEL,
        max_output_tokens=65536,
    )
    return model_used, result


async def _call_via_realtime(
    prompt: str,
    system: str,
    tool: dict,
    tool_name: str,
) -> tuple[str, dict[str, Any]]:
    """Fallback: try realtime cascade with Deep Think."""
    for i, (model, thinking_level, force_aistudio) in enumerate(REALTIME_CASCADE):
        try:
            think_tag = f" [DeepThink={thinking_level}]" if thinking_level else ""
            api_tag = " [AIStudio]" if force_aistudio else " [VertexAI]"
            logger.info(f"[AUDIT/RT] Trying {model}{think_tag}{api_tag} ({i+1}/{len(REALTIME_CASCADE)})...")
            result = await generate_with_tool(
                prompt=prompt,
                system=system,
                tool=tool,
                tool_name=tool_name,
                provider=Provider.GEMINI,
                model=model,
                thinking_level=thinking_level,
                force_aistudio=force_aistudio,
            )
            logger.info(f"[AUDIT/RT] ✓ Success with {model}{think_tag}{api_tag}")
            return f"{model}{think_tag}{api_tag}", result
        except (ValueError, Exception) as exc:
            exc_str = str(exc).lower()
            if "429" in exc_str or "404" in exc_str or "rate" in exc_str or "resource_exhausted" in exc_str:
                logger.warning(f"[AUDIT/RT] ✗ {model}{think_tag}{api_tag}: {exc}")
                continue
            raise

    models_str = [f"{m}({t or 'default'},{('ai_studio' if a else 'vertex')})" for m, t, a in REALTIME_CASCADE]
    alarm = (
        f"[AUDIT ALARM] All models exhausted: {models_str}\n"
        f"Likely daily quota reached. Check https://aistudio.google.com/apikey"
    )
    logger.error(alarm)
    raise RuntimeError(alarm)


# ─── Phase 1: Meta-Audit ───────────────────────────────────────────

async def run_meta_audit(
    master_document: str,
    model_type: str = "tank",
) -> dict[str, Any]:
    """Phase 1: Submit Master Document to Ultra for meta-audit.

    Uses batch prediction (no truncation) with realtime fallback.
    """
    system = (
        "You are the Chief Inspector (Gemini Ultra) performing a Phase 1 Meta-Audit. "
        "You are evaluating a Master Document BEFORE any CAD design begins. "
        "Your job is to catch conceptual errors, missing circuits, philosophy violations, "
        "and proportion impossibilities EARLY — before any tokens are spent on CAD generation. "
        "Be thorough but fair. Approve only if the document is sound."
    )

    prompt = (
        f"## Phase 1 Meta-Audit: {model_type}\n\n"
        f"### Master Document\n{master_document}\n\n"
        "### Evaluate:\n"
        "1. Are the overall size proportions physically coherent at this scale?\n"
        "2. Is the electronic circuit complete (voltages, current paths, wiring)?\n"
        "3. Does it follow the Universal Modular Insert Standard (M2/M3/M4, removable inserts)?\n"
        "4. Is modularity adequate (screw access, insert accessibility, wire routing)?\n"
        "If any criterion fails, set approval='REVISE' and list specific issues with fixes."
    )

    model_used, result = await _call_audit(prompt, system, META_AUDIT_TOOL, "meta_audit")
    logger.info(
        f"[META_AUDIT] {result.get('approval', '?')} via {model_used} — "
        f"proportions={result.get('proportions_ok')}, circuit={result.get('circuit_ok')}, "
        f"philosophy={result.get('philosophy_ok')}, modularity={result.get('modularity_ok')}"
    )
    result["_model_used"] = model_used
    return result


# ─── Phase 3: Grand Audit ──────────────────────────────────────────

async def run_grand_audit(
    stage_results: dict[str, Any],
    scad_sources: dict[str, str],
    model_type: str = "tank",
    model_name: str = "M1A1 Abrams",
    assembly_manual: str | None = None,
) -> dict[str, Any]:
    """Phase 3: Submit all stage results + code to Ultra for Grand Audit.

    Uses batch prediction (no truncation) with realtime fallback.
    Returns verdict (PASS/FAIL), issues, prompt updates, and delta feedback.
    """
    system = (
        f"You are the Chief Inspector (Gemini Ultra) performing the Phase 3 Grand Audit "
        f"for a {model_name} ({model_type}). All 4 intermediate stages scored 10/10. "
        f"Your job is to find what they MISSED. You have zero tolerance for:\n"
        f"1. Core gimmick failures (play feature doesn't work mechanically)\n"
        f"2. Assembly impossibilities (screwdriver can't reach, wires pinched)\n"
        f"3. Structural holes (USB-C blocked, walls not sealed)\n"
        f"4. Kinematic/dynamic failures (motors wrong, CoG causes tipping)\n"
        f"5. Thermal/power risks (ESP32 overheats, battery over-discharge)\n\n"
        f"If you find a critical error, you MUST also evaluate: "
        f"'Why did Stages 1-4 miss this?' and mandate a prompt update.\n"
        f"Issue delta-feedback with specific files to fix and resubmit scope."
    )

    # Build prompt with all stage results and full SCAD source
    # Batch mode has no token limit concerns — send everything
    prompt_parts = [f"## Grand Audit: {model_name}\n\n"]

    prompt_parts.append("### Stage Results (all 10/10)\n")
    for stage_name, stage_data in stage_results.items():
        prompt_parts.append(f"**{stage_name}:** {json.dumps(stage_data, indent=1)}\n")

    prompt_parts.append("\n### OpenSCAD Source Code (FULL — for thorough audit)\n")
    for filename, source in scad_sources.items():
        prompt_parts.append(f"**{filename}:**\n```scad\n{source}\n```\n\n")

    if assembly_manual:
        prompt_parts.append(f"\n### Assembly Manual\n{assembly_manual}\n")

    prompt_parts.append(
        "\n### Instructions\n"
        "Perform the 5-criterion Grand Audit. If ALL pass, verdict='PASS'. "
        "If ANY critical issue, verdict='FAIL' with delta-feedback.\n"
        "If you find something Stages 1-4 should have caught, add a prompt_update entry."
    )

    model_used, result = await _call_audit(
        "".join(prompt_parts), system, GRAND_AUDIT_TOOL, "grand_audit"
    )

    verdict = result.get("verdict", "FAIL")
    logger.info(
        f"[GRAND_AUDIT] {verdict} via {model_used} — "
        f"gimmick={result.get('core_gimmick_ok')}, manual={result.get('manual_realism_ok')}, "
        f"structural={result.get('structural_ok')}, kinematics={result.get('kinematics_ok')}, "
        f"thermal={result.get('thermal_ok')}"
    )

    # Apply meta-corrections to audit prompts if any
    prompt_updates = result.get("prompt_updates", [])
    if prompt_updates:
        await _apply_prompt_updates(prompt_updates)

    result["_model_used"] = model_used
    return result


async def _apply_prompt_updates(updates: list[dict]) -> None:
    """Save Ultra's meta-corrections to audit_prompts.json."""
    prompts_path = Path(__file__).parent / "audit_prompts.json"
    existing = {}
    if prompts_path.exists():
        existing = json.loads(prompts_path.read_text(encoding="utf-8"))

    for update in updates:
        stage = f"stage_{update.get('stage', 0)}"
        if stage not in existing:
            existing[stage] = {"additions": []}
        existing[stage]["additions"].append({
            "check": update.get("addition", ""),
            "reason": update.get("reason", ""),
        })
        logger.info(
            f"[META_CORRECTION] Stage {update.get('stage')}: "
            f"Added check: {update.get('addition', '')[:80]}..."
        )

    prompts_path.write_text(json.dumps(existing, indent=2), encoding="utf-8")
    logger.info(f"[META_CORRECTION] Saved {len(updates)} prompt updates to {prompts_path}")


# ─── Pipeline State ────────────────────────────────────────────────

PIPELINE_STATES = [
    "inception",
    "ultra_meta_audit",
    "stage_1_proportions",
    "stage_2_physics",
    "stage_3_printability",
    "stage_4_aesthetics",
    "generating_sim_3mf",
    "ultra_grand_audit",
    "loop_resolution",
    "final_report",
]


def get_pipeline_state(project_dir: Path) -> dict[str, Any]:
    """Read current pipeline state from JSON."""
    state_path = project_dir / "pipeline_state.json"
    if state_path.exists():
        return json.loads(state_path.read_text(encoding="utf-8"))
    return {
        "current_state": "inception",
        "states": {s: {"status": "pending", "score": None} for s in PIPELINE_STATES},
        "history": [],
    }


def set_pipeline_state(
    project_dir: Path,
    state: str,
    status: str = "in_progress",
    score: int | None = None,
    notes: str = "",
) -> None:
    """Update pipeline state and append to history."""
    current = get_pipeline_state(project_dir)
    current["current_state"] = state
    current["states"][state] = {"status": status, "score": score}
    current["history"].append({
        "state": state,
        "status": status,
        "score": score,
        "notes": notes,
    })
    state_path = project_dir / "pipeline_state.json"
    state_path.write_text(json.dumps(current, indent=2), encoding="utf-8")
