"""Reference search module — Step 1 of the pipeline.

Uses Claude Sonnet to generate search queries from user intent,
fetches web results, then sends to Gemini for proportional analysis.
"""

import json
import logging
from typing import Any

import httpx

from planning_server.app import config
from planning_server.app.pipeline.llm import Provider, generate_text, generate_with_tool

logger = logging.getLogger(__name__)

# Tool schema for Sonnet to generate search queries
SEARCH_QUERIES_TOOL = {
    "name": "search_queries",
    "description": "Generate targeted web search queries to find reference specifications for a robot model.",
    "input_schema": {
        "type": "object",
        "properties": {
            "model_name": {
                "type": "string",
                "description": "The identified real-world vehicle/robot name (e.g., 'M1A1 Abrams')",
            },
            "queries": {
                "type": "array",
                "items": {"type": "string"},
                "description": "3-5 targeted search queries to find exact dimensions, proportions, and shape details",
            },
            "key_features": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Key visual/structural features to look for (e.g., 'glacis angle', 'turret cheek armor shape')",
            },
        },
        "required": ["model_name", "queries", "key_features"],
    },
}

# Tool schema for structured proportional data output from Gemini
PROPORTIONS_TOOL = {
    "name": "proportional_analysis",
    "description": "Structured proportional analysis of a vehicle for 3D CAD modeling.",
    "input_schema": {
        "type": "object",
        "properties": {
            "model_name": {"type": "string"},
            "scale": {"type": "string", "description": "Target scale (e.g., '1:10')"},
            "real_dimensions_mm": {
                "type": "object",
                "description": "Full-scale dimensions in mm",
                "properties": {
                    "overall_length_gun_forward": {"type": "number"},
                    "hull_length": {"type": "number"},
                    "hull_width": {"type": "number"},
                    "hull_height": {"type": "number"},
                    "turret_length": {"type": "number"},
                    "turret_width": {"type": "number"},
                    "turret_height": {"type": "number"},
                    "track_width": {"type": "number"},
                    "track_ground_contact_length": {"type": "number"},
                    "ground_clearance": {"type": "number"},
                    "gun_barrel_length": {"type": "number"},
                    "turret_ring_diameter": {"type": "number"},
                },
            },
            "scaled_dimensions_mm": {
                "type": "object",
                "description": "Dimensions at target scale in mm",
                "properties": {
                    "hull_length": {"type": "number"},
                    "hull_width": {"type": "number"},
                    "hull_height": {"type": "number"},
                    "turret_length": {"type": "number"},
                    "turret_width": {"type": "number"},
                    "turret_height": {"type": "number"},
                    "track_width": {"type": "number"},
                    "track_ground_contact_length": {"type": "number"},
                    "ground_clearance": {"type": "number"},
                    "gun_barrel_length": {"type": "number"},
                    "turret_ring_diameter": {"type": "number"},
                },
            },
            "proportional_ratios": {
                "type": "object",
                "description": "Key ratios for shape accuracy",
                "properties": {
                    "hull_length_to_width": {"type": "number"},
                    "hull_length_to_height": {"type": "number"},
                    "turret_length_to_hull_length": {"type": "number"},
                    "turret_width_to_hull_width": {"type": "number"},
                    "track_length_to_hull_length": {"type": "number"},
                    "barrel_length_to_turret_length": {"type": "number"},
                    "ground_clearance_to_hull_height": {"type": "number"},
                },
            },
            "shape_notes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "feature": {"type": "string"},
                        "description": {"type": "string"},
                        "angle_degrees": {"type": "number"},
                    },
                },
                "description": "Key shape features for CAD modeling (angles, curves, slopes)",
            },
            "road_wheels": {
                "type": "object",
                "properties": {
                    "count_per_side": {"type": "integer"},
                    "diameter_mm_scaled": {"type": "number"},
                    "spacing_mm_scaled": {"type": "number"},
                },
            },
            "printability_notes": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Notes on how to split/adapt for 180x180x180mm build volume",
            },
        },
        "required": [
            "model_name", "scale", "real_dimensions_mm",
            "scaled_dimensions_mm", "proportional_ratios", "shape_notes",
        ],
    },
}


async def _web_search(query: str) -> list[dict[str, str]]:
    """Perform a web search via SerpAPI or fallback.

    Returns list of {title, snippet, link}.
    """
    serp_key = getattr(config, "SERPAPI_KEY", None) or ""
    if serp_key:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(
                "https://serpapi.com/search",
                params={"q": query, "api_key": serp_key, "num": 5},
            )
            data = resp.json()
            return [
                {"title": r.get("title", ""), "snippet": r.get("snippet", ""), "link": r.get("link", "")}
                for r in data.get("organic_results", [])[:5]
            ]

    # Fallback: use LLM knowledge (no live search available server-side)
    logger.warning("No SERPAPI_KEY configured — using LLM knowledge for reference data")
    return []


async def generate_search_queries(
    user_prompt: str,
    provider: Provider = Provider.CLAUDE,
) -> dict[str, Any]:
    """Use Sonnet to analyze user intent and generate targeted search queries.

    Args:
        user_prompt: The user's natural language request.
        provider: LLM provider (default: Claude Sonnet).

    Returns:
        Dict with model_name, queries, and key_features.
    """
    system = (
        "You are a research assistant for a robotics project. "
        "The user wants to build a scale model of a real-world vehicle. "
        "Analyze their request and generate specific web search queries "
        "to find exact dimensions, blueprints, and shape specifications. "
        "Focus on queries that will return numerical data (mm, inches, degrees) "
        "and detailed shape descriptions useful for CAD modeling."
    )

    result = await generate_with_tool(
        prompt=user_prompt,
        system=system,
        tool=SEARCH_QUERIES_TOOL,
        tool_name="search_queries",
        provider=provider,
    )

    logger.info(f"Generated {len(result.get('queries', []))} search queries for '{result.get('model_name')}'")
    return result


async def fetch_reference_data(
    queries: list[str],
    key_features: list[str],
) -> str:
    """Execute search queries and compile results into a reference document.

    Args:
        queries: Search queries to execute.
        key_features: Features to look for in results.

    Returns:
        Compiled reference text for Gemini analysis.
    """
    all_results = []
    for query in queries:
        results = await _web_search(query)
        for r in results:
            if r.get("snippet"):
                all_results.append(f"**{r['title']}**: {r['snippet']}")

    if all_results:
        return (
            "## Web Search Results\n\n"
            + "\n\n".join(all_results)
            + "\n\n## Key Features to Identify\n"
            + "\n".join(f"- {f}" for f in key_features)
        )

    # No search API — return a prompt for LLM to use its training data
    return (
        "No live search results available. Use your training data to provide "
        "accurate specifications. Key features to include:\n"
        + "\n".join(f"- {f}" for f in key_features)
    )


async def analyze_proportions(
    model_name: str,
    reference_data: str,
    scale: str = "1:10",
    build_volume_mm: tuple[int, int, int] = (180, 180, 180),
    provider: Provider = Provider.GEMINI,
) -> dict[str, Any]:
    """Send reference data to Gemini for proportional analysis.

    Args:
        model_name: Vehicle/robot name.
        reference_data: Compiled reference text from web search.
        scale: Target scale for the model.
        build_volume_mm: 3D printer build volume constraint.
        provider: LLM provider (default: Gemini for vision/analysis).

    Returns:
        Structured proportional analysis dict.
    """
    system = (
        f"You are a mechanical engineer analyzing reference data for a {scale} scale "
        f"3D-printable model of a {model_name}. Your analysis must be precise and "
        f"numerically accurate. All dimensions must be consistent with real-world "
        f"specifications. The model must fit within a {build_volume_mm[0]}x"
        f"{build_volume_mm[1]}x{build_volume_mm[2]}mm 3D printer build volume "
        f"(parts can be split across multiple prints).\n\n"
        f"Focus on proportional accuracy — the ratios between parts matter more "
        f"than exact scale. A turret that's the wrong width relative to the hull "
        f"will look wrong even if the overall size is correct."
    )

    prompt = (
        f"Analyze the following reference data for a {model_name} and produce "
        f"a complete proportional specification at {scale} scale.\n\n"
        f"{reference_data}\n\n"
        f"Calculate all dimensions at {scale} scale. Identify key shape features "
        f"(angles, slopes, curves) critical for visual accuracy. Note any parts "
        f"that need splitting for the build volume."
    )

    result = await generate_with_tool(
        prompt=prompt,
        system=system,
        tool=PROPORTIONS_TOOL,
        tool_name="proportional_analysis",
        provider=provider,
    )

    logger.info(
        f"Proportional analysis complete for {model_name}: "
        f"{len(result.get('shape_notes', []))} shape notes, "
        f"{len(result.get('printability_notes', []))} print notes"
    )
    return result


async def search_and_analyze(
    user_prompt: str,
    scale: str = "1:10",
    build_volume_mm: tuple[int, int, int] = (180, 180, 180),
) -> dict[str, Any]:
    """Full Step 1: User intent → search → proportional analysis.

    This is the main entry point for the reference search pipeline step.

    Args:
        user_prompt: Natural language description of what to build.
        scale: Target scale.
        build_volume_mm: Printer build volume.

    Returns:
        Complete proportional analysis dict.
    """
    # 1. Sonnet generates search queries from user intent
    search_plan = await generate_search_queries(user_prompt, provider=Provider.CLAUDE)
    model_name = search_plan.get("model_name", "Unknown")

    # 2. Execute searches and compile reference data
    reference_data = await fetch_reference_data(
        queries=search_plan.get("queries", []),
        key_features=search_plan.get("key_features", []),
    )

    # 3. Gemini analyzes proportions
    analysis = await analyze_proportions(
        model_name=model_name,
        reference_data=reference_data,
        scale=scale,
        build_volume_mm=build_volume_mm,
        provider=Provider.GEMINI,
    )

    return analysis
