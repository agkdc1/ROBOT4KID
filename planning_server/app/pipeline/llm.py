"""LLM provider abstraction — Claude (primary) and Gemini (secondary).

Claude Sonnet is used for complex tasks: 3D modeling, planning, structured generation.
Gemini is available for simpler tasks and expansion.
"""

import logging
from enum import Enum

from anthropic import AsyncAnthropic
from google import genai

from planning_server.app import config

logger = logging.getLogger(__name__)


class Provider(str, Enum):
    CLAUDE = "claude"
    GEMINI = "gemini"


def _get_claude_client() -> AsyncAnthropic:
    if not config.ANTHROPIC_API_KEY:
        raise ValueError("ANTHROPIC_API_KEY not set")
    return AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)


def _get_gemini_client() -> genai.Client:
    if not config.GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY not set")
    return genai.Client(api_key=config.GEMINI_API_KEY)


async def generate_text(
    prompt: str,
    system: str = "",
    provider: Provider = Provider.CLAUDE,
    model: str | None = None,
    max_tokens: int = 4096,
) -> str:
    """Generate text from either Claude or Gemini.

    Args:
        prompt: User message.
        system: System prompt.
        provider: Which LLM to use.
        model: Model override.
        max_tokens: Max output tokens.

    Returns:
        Generated text string.
    """
    if provider == Provider.CLAUDE:
        return await _claude_text(prompt, system, model, max_tokens)
    else:
        return await _gemini_text(prompt, system, model, max_tokens)


async def generate_with_tool(
    prompt: str,
    system: str,
    tool: dict,
    tool_name: str,
    provider: Provider = Provider.CLAUDE,
    model: str | None = None,
    max_tokens: int = 8192,
) -> dict:
    """Generate structured output using tool/function calling.

    Args:
        prompt: User message.
        system: System prompt.
        tool: Tool definition (Claude format).
        tool_name: Name of the tool to force.
        provider: Which LLM to use.
        model: Model override.
        max_tokens: Max output tokens.

    Returns:
        Parsed tool input dict.
    """
    if provider == Provider.CLAUDE:
        return await _claude_tool_call(prompt, system, tool, tool_name, model, max_tokens)
    else:
        return await _gemini_tool_call(prompt, system, tool, tool_name, model, max_tokens)


async def _claude_text(prompt: str, system: str, model: str | None, max_tokens: int) -> str:
    client = _get_claude_client()
    model = model or config.CLAUDE_MODEL_FAST

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = await client.messages.create(
                model=model,
                max_tokens=max_tokens,
                system=system,
                messages=[{"role": "user", "content": prompt}],
            )
            text = response.content[0].text.strip()
            # Strip markdown fences if present
            if text.startswith("```"):
                lines = text.split("\n")
                text = "\n".join(lines[1:])
                if text.endswith("```"):
                    text = text[:-3].strip()
            return text
        except Exception as e:
            logger.warning(f"Claude text attempt {attempt + 1} failed: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"Claude text generation failed: {e}")
    raise ValueError("Claude text generation failed")


async def _claude_tool_call(
    prompt: str, system: str, tool: dict, tool_name: str, model: str | None, max_tokens: int,
) -> dict:
    client = _get_claude_client()
    model = model or config.CLAUDE_MODEL_FAST

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = await client.messages.create(
                model=model,
                max_tokens=max_tokens,
                system=system,
                tools=[tool],
                tool_choice={"type": "tool", "name": tool_name},
                messages=[{"role": "user", "content": prompt}],
            )
            for block in response.content:
                if block.type == "tool_use" and block.name == tool_name:
                    return block.input
            raise ValueError(f"No {tool_name} tool_use in response")
        except Exception as e:
            logger.warning(f"Claude tool call attempt {attempt + 1} failed: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"Claude tool call failed: {e}")
    raise ValueError("Claude tool call failed")


async def _gemini_text(prompt: str, system: str, model: str | None, max_tokens: int) -> str:
    client = _get_gemini_client()
    model = model or config.GEMINI_MODEL

    full_prompt = f"{system}\n\n{prompt}" if system else prompt

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = client.models.generate_content(
                model=model,
                contents=full_prompt,
                config=genai.types.GenerateContentConfig(
                    max_output_tokens=max_tokens,
                ),
            )
            text = response.text.strip()
            if text.startswith("```"):
                lines = text.split("\n")
                text = "\n".join(lines[1:])
                if text.endswith("```"):
                    text = text[:-3].strip()
            return text
        except Exception as e:
            logger.warning(f"Gemini text attempt {attempt + 1} failed: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"Gemini text generation failed: {e}")
    raise ValueError("Gemini text generation failed")


async def _gemini_tool_call(
    prompt: str, system: str, tool: dict, tool_name: str, model: str | None, max_tokens: int,
) -> dict:
    """Gemini structured output via response_schema (JSON mode)."""
    import json
    client = _get_gemini_client()
    model = model or config.GEMINI_MODEL

    full_prompt = (
        f"{system}\n\n{prompt}\n\n"
        f"Respond with a valid JSON object matching this schema:\n"
        f"{json.dumps(tool.get('input_schema', {}), indent=2)}"
    )

    for attempt in range(config.CLAUDE_MAX_RETRIES):
        try:
            response = client.models.generate_content(
                model=model,
                contents=full_prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    max_output_tokens=max_tokens,
                ),
            )
            text = response.text.strip()
            return json.loads(text)
        except Exception as e:
            logger.warning(f"Gemini tool call attempt {attempt + 1} failed: {e}")
            if attempt == config.CLAUDE_MAX_RETRIES - 1:
                raise ValueError(f"Gemini tool call failed: {e}")
    raise ValueError("Gemini tool call failed")
