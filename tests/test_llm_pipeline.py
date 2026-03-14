"""Test and evaluate LLM pipeline outputs against the M1A1 reference spec.

Usage:
    python -m tests.test_llm_pipeline [--provider claude|gemini] [--step nlp|cad|all]
"""

import asyncio
import json
import logging
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from dotenv import load_dotenv
load_dotenv(PROJECT_ROOT / ".env")

from planning_server.app.pipeline.llm import Provider
from planning_server.app.pipeline.nlp import parse_nl_to_robot_spec
from planning_server.app.pipeline.cad_gen import generate_scad_for_part
from shared.schemas.robot_spec import RobotSpec, PrinterProfile

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

REFERENCE_SPEC_PATH = PROJECT_ROOT / "tests" / "m1a1_reference_spec.json"

M1A1_PROMPT = """Design a 1/10 scale M1A1 Abrams main battle tank for 3D printing on a Bambu Lab A1 Mini.

Requirements:
- Hull chassis split into front and rear halves (each must fit 180x180x180mm build volume)
- Left and right track assemblies
- Rotating turret with gun barrel that has elevation control
- Battery compartment in hull for 2S LiPo
- Motor mounts for 2x DC gear motors (differential drive)
- Electronics bay for ESP32-CAM, motor driver (L9110), and gyro (MPU6050)
- Turret has its own ESP32-CAM, elevation servo, rotation motor, VL53L0X ToF sensor
- All parts joined with M4 hardware
- Tablet-controlled via WiFi (AP mode on hull ESP32-CAM)
- Overall dimensions: ~300mm long, 140mm wide, 130mm tall with turret
"""


def load_reference() -> RobotSpec:
    data = json.loads(REFERENCE_SPEC_PATH.read_text())
    return RobotSpec.model_validate(data)


def evaluate_spec(generated: RobotSpec, reference: RobotSpec) -> dict:
    """Compare generated spec against reference and score."""
    scores = {}

    # 1. Parts coverage — check if key part categories are present
    ref_part_ids = {p.id for p in reference.parts}
    gen_part_ids = {p.id for p in generated.parts}
    ref_categories = {p.category for p in reference.parts}
    gen_categories = {p.category for p in generated.parts}

    scores["part_count"] = {
        "reference": len(reference.parts),
        "generated": len(generated.parts),
        "score": min(len(generated.parts) / max(len(reference.parts), 1), 1.5),
    }

    scores["category_coverage"] = {
        "reference": sorted(ref_categories),
        "generated": sorted(gen_categories),
        "missing": sorted(ref_categories - gen_categories),
        "score": len(ref_categories & gen_categories) / max(len(ref_categories), 1),
    }

    # 2. Check key parts exist (by name similarity)
    key_parts = ["hull", "track", "turret", "barrel", "battery", "motor", "electronics"]
    found = 0
    for key in key_parts:
        if any(key in p.id.lower() or key in p.name.lower() for p in generated.parts):
            found += 1
    scores["key_parts"] = {
        "expected": key_parts,
        "found": found,
        "score": found / len(key_parts),
    }

    # 3. Build volume compliance
    violations = []
    for part in generated.parts:
        dims = part.dimensions_mm
        if not part.requires_splitting and any(d > 180 for d in dims):
            violations.append(f"{part.id}: {dims}")
    scores["build_volume"] = {
        "violations": violations,
        "score": 1.0 if not violations else max(0, 1 - len(violations) * 0.2),
    }

    # 4. Joints
    ref_joint_types = {j.type.value for j in reference.joints}
    gen_joint_types = {j.type.value for j in generated.joints}
    scores["joints"] = {
        "reference_count": len(reference.joints),
        "generated_count": len(generated.joints),
        "has_revolute": "revolute" in gen_joint_types,
        "has_fixed": "fixed" in gen_joint_types,
        "score": min(len(generated.joints) / max(len(reference.joints), 1), 1.5)
               * (1.0 if "revolute" in gen_joint_types else 0.5),
    }

    # 5. Electronics
    ref_types = {e.type for e in reference.electronics}
    gen_types = {e.type for e in generated.electronics}
    scores["electronics"] = {
        "reference_types": sorted(ref_types),
        "generated_types": sorted(gen_types),
        "score": len(ref_types & gen_types) / max(len(ref_types), 1),
    }

    # 6. Firmware config
    ref_keys = set(reference.firmware_config.keys())
    gen_keys = set(generated.firmware_config.keys())
    scores["firmware_config"] = {
        "reference_keys": sorted(ref_keys),
        "generated_keys": sorted(gen_keys),
        "score": len(ref_keys & gen_keys) / max(len(ref_keys), 1),
    }

    # Overall score
    weights = {
        "part_count": 0.15,
        "category_coverage": 0.15,
        "key_parts": 0.25,
        "build_volume": 0.15,
        "joints": 0.15,
        "electronics": 0.10,
        "firmware_config": 0.05,
    }
    overall = sum(scores[k]["score"] * weights[k] for k in weights)
    scores["overall"] = round(overall, 3)

    return scores


def evaluate_scad(code: str, part_id: str) -> dict:
    """Basic evaluation of generated OpenSCAD code."""
    checks = {}

    checks["non_empty"] = len(code) > 50
    checks["has_fn"] = "$fn" in code
    checks["has_module"] = "module " in code
    checks["has_difference"] = "difference()" in code
    checks["has_variables"] = code.count("=") >= 3 and not code.startswith("//")
    checks["has_comments"] = "//" in code
    checks["no_markdown"] = "```" not in code
    checks["has_dimensions"] = any(
        dim in code.lower()
        for dim in ["width", "height", "length", "diameter", "thickness", "wall"]
    )

    score = sum(checks.values()) / len(checks)
    return {"part_id": part_id, "checks": checks, "score": round(score, 3)}


async def test_nlp(provider: Provider) -> tuple[RobotSpec | None, dict]:
    """Test NLP parsing step."""
    logger.info(f"\n{'='*60}")
    logger.info(f"Testing NLP Parse — Provider: {provider.value}")
    logger.info(f"{'='*60}")

    reference = load_reference()

    try:
        generated = await parse_nl_to_robot_spec(M1A1_PROMPT, provider=provider)
        scores = evaluate_spec(generated, reference)

        logger.info(f"\nResults:")
        logger.info(f"  Name: {generated.name}")
        logger.info(f"  Parts: {len(generated.parts)}")
        logger.info(f"  Joints: {len(generated.joints)}")
        logger.info(f"  Electronics: {len(generated.electronics)}")
        logger.info(f"  Overall Score: {scores['overall']:.1%}")

        for key, val in scores.items():
            if key != "overall" and isinstance(val, dict):
                logger.info(f"  {key}: {val.get('score', 'N/A'):.1%}")

        return generated, scores

    except Exception as e:
        logger.error(f"NLP test failed: {e}")
        return None, {"error": str(e), "overall": 0}


async def test_cad(spec: RobotSpec, provider: Provider) -> list[dict]:
    """Test CAD generation for each part."""
    logger.info(f"\n{'='*60}")
    logger.info(f"Testing CAD Generation — Provider: {provider.value}")
    logger.info(f"{'='*60}")

    results = []
    for part in spec.parts[:3]:  # Test first 3 parts to save tokens
        try:
            code = await generate_scad_for_part(
                part, spec.printer, provider=provider,
            )
            eval_result = evaluate_scad(code, part.id)
            results.append(eval_result)
            logger.info(f"  {part.id}: score={eval_result['score']:.1%}, "
                        f"len={len(code)} chars")
        except Exception as e:
            logger.error(f"  {part.id}: FAILED — {e}")
            results.append({"part_id": part.id, "error": str(e), "score": 0})

    avg_score = sum(r["score"] for r in results) / max(len(results), 1)
    logger.info(f"\n  Average CAD Score: {avg_score:.1%}")
    return results


async def main():
    import argparse
    parser = argparse.ArgumentParser(description="Test LLM pipeline")
    parser.add_argument("--provider", choices=["claude", "gemini"], default="claude")
    parser.add_argument("--step", choices=["nlp", "cad", "all"], default="all")
    args = parser.parse_args()

    provider = Provider.CLAUDE if args.provider == "claude" else Provider.GEMINI

    results = {"provider": args.provider}

    if args.step in ("nlp", "all"):
        spec, nlp_scores = await test_nlp(provider)
        results["nlp"] = nlp_scores

        if args.step == "all" and spec:
            cad_results = await test_cad(spec, provider)
            results["cad"] = cad_results
    elif args.step == "cad":
        reference = load_reference()
        cad_results = await test_cad(reference, provider)
        results["cad"] = cad_results

    # Save results
    output_path = PROJECT_ROOT / "tests" / f"eval_{args.provider}.json"
    output_path.write_text(json.dumps(results, indent=2, default=str))
    logger.info(f"\nResults saved to {output_path}")


if __name__ == "__main__":
    asyncio.run(main())
