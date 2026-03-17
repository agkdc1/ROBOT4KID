"""Multi-Agent Debate with Human Referee.

Implements a structured debate loop between Claude (Engineer) and Gemini (Auditor)
with automatic escalation to the user when consensus isn't reached.

Flow:
1. Claude generates/fixes CAD based on requirements
2. Gemini audits with model-specific physics context
3. If score >= threshold: APPROVED, exit loop
4. If score < threshold: Claude acknowledges issues and proposes fixes
5. After MAX_ROUNDS without agreement: escalate to user as referee
6. User selects from options or provides direction

The user can also intervene at any point to modify the audit prompt
or override a decision.
"""

import json
import logging
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Callable

logger = logging.getLogger(__name__)

MAX_DEBATE_ROUNDS = 3  # Before escalating to user
GATE1_THRESHOLD = 7    # Visual quality score /10
GATE2_THRESHOLD = 8


class DebateOutcome(str, Enum):
    APPROVED = "approved"
    REJECTED = "rejected"
    ESCALATED = "escalated"      # Sent to user for referee decision
    USER_OVERRIDE = "user_override"


@dataclass
class DebateRound:
    """One round of the Claude-Gemini debate."""
    round_number: int
    gemini_score: int
    gemini_passes: list[str]
    gemini_issues: list[str]
    gemini_fixes: list[str]
    claude_response: str = ""    # Claude's acknowledgement + proposed fix
    structural_clearance: str = "PENDING"


@dataclass
class DebateResult:
    """Final result of a debate session."""
    outcome: DebateOutcome
    final_score: int
    rounds: list[DebateRound]
    summary: str = ""
    user_options: list[dict] = field(default_factory=list)  # For escalation
    user_choice: str = ""        # User's referee decision

    def to_dict(self) -> dict:
        return {
            "outcome": self.outcome.value,
            "final_score": self.final_score,
            "total_rounds": len(self.rounds),
            "summary": self.summary,
            "user_options": self.user_options,
            "user_choice": self.user_choice,
            "rounds": [
                {
                    "round": r.round_number,
                    "score": r.gemini_score,
                    "passes": r.gemini_passes,
                    "issues": r.gemini_issues,
                    "fixes": r.gemini_fixes,
                    "claude_response": r.claude_response,
                    "structural_clearance": r.structural_clearance,
                }
                for r in self.rounds
            ],
        }


def build_escalation_summary(rounds: list[DebateRound], model_name: str) -> tuple[str, list[dict]]:
    """Build a human-readable summary and options for referee decision.

    Returns:
        (summary_text, options_list) for presenting to user.
    """
    summary_lines = [
        f"## Debate Escalation: {model_name}",
        f"After {len(rounds)} rounds, Claude and Gemini cannot agree.",
        "",
        "### Round History:",
    ]

    persistent_issues = {}  # Track issues across rounds
    for r in rounds:
        summary_lines.append(f"\n**Round {r.round_number}** (Score: {r.gemini_score}/10)")
        for issue in r.gemini_issues:
            summary_lines.append(f"  - [ISSUE] {issue}")
            persistent_issues[issue] = persistent_issues.get(issue, 0) + 1
        if r.claude_response:
            summary_lines.append(f"  - [CLAUDE] {r.claude_response[:200]}")

    # Identify recurring issues
    recurring = {k: v for k, v in persistent_issues.items() if v >= 2}
    if recurring:
        summary_lines.append("\n### Recurring Issues (flagged every round):")
        for issue, count in recurring.items():
            summary_lines.append(f"  - ({count}x) {issue}")

    summary_lines.append("\n### Latest Gemini Mandatory Fixes:")
    if rounds:
        for fix in rounds[-1].gemini_fixes:
            summary_lines.append(f"  - {fix}")

    summary = "\n".join(summary_lines)

    # Build options for user
    options = [
        {
            "id": "accept_current",
            "label": "Accept current design (override Gemini)",
            "description": "The design is good enough. Proceed without further changes.",
        },
        {
            "id": "apply_fixes",
            "label": "Apply Gemini's mandatory fixes",
            "description": "Let Claude implement all remaining fixes and re-audit.",
        },
        {
            "id": "modify_audit",
            "label": "Modify audit criteria",
            "description": "Adjust what Gemini checks for (e.g., relax aesthetic requirements).",
        },
        {
            "id": "custom_direction",
            "label": "Provide custom direction",
            "description": "Give specific instructions for what to fix or change.",
        },
    ]

    # Add issue-specific options for recurring problems
    for issue in list(recurring.keys())[:3]:
        options.append({
            "id": f"dismiss_{hash(issue) % 10000}",
            "label": f"Dismiss: \"{issue[:60]}...\"",
            "description": "This is intentional / not a real issue. Tell Gemini to ignore it.",
        })

    return summary, options


async def run_debate(
    model_name: str,
    model_type: str,
    audit_fn: Callable,
    fix_fn: Callable,
    threshold: int = GATE1_THRESHOLD,
    max_rounds: int = MAX_DEBATE_ROUNDS,
    user_callback: Callable | None = None,
) -> DebateResult:
    """Run a structured debate between Claude and Gemini.

    Args:
        model_name: Name of the model being debated.
        model_type: "tank", "train", etc.
        audit_fn: Async function that runs Gemini audit, returns dict with
                  score, passes, issues, mandatory_fixes, structural_clearance.
        fix_fn: Async function that applies fixes based on issues list,
                returns string describing what was fixed.
        threshold: Minimum score to approve.
        max_rounds: Max rounds before escalating to user.
        user_callback: Optional async callback for user referee input.
                       Called with (summary, options) -> returns chosen option dict.

    Returns:
        DebateResult with outcome and full history.
    """
    rounds = []

    for round_num in range(1, max_rounds + 1):
        logger.info(f"[Debate] Round {round_num}/{max_rounds} for {model_name}")

        # 1. Gemini audits
        audit_result = await audit_fn()
        score = audit_result.get("score", audit_result.get("visual_quality_score", 0))
        passes = audit_result.get("passes", [])
        issues = audit_result.get("issues", [])
        fixes = audit_result.get("mandatory_fixes", [])
        clearance = audit_result.get("structural_clearance", "PENDING")

        debate_round = DebateRound(
            round_number=round_num,
            gemini_score=score,
            gemini_passes=passes,
            gemini_issues=issues,
            gemini_fixes=fixes,
            structural_clearance=clearance,
        )

        # 2. Check if approved
        if score >= threshold and not fixes:
            debate_round.claude_response = "All checks passed. No fixes needed."
            rounds.append(debate_round)
            logger.info(f"[Debate] APPROVED at round {round_num} (score: {score}/10)")
            return DebateResult(
                outcome=DebateOutcome.APPROVED,
                final_score=score,
                rounds=rounds,
                summary=f"Approved after {round_num} round(s) with score {score}/10.",
            )

        # 3. Claude acknowledges and fixes
        if fixes or issues:
            claude_response = await fix_fn(issues, fixes)
            debate_round.claude_response = claude_response
        else:
            debate_round.claude_response = "Score below threshold but no specific fixes requested."

        rounds.append(debate_round)
        logger.info(
            f"[Debate] Round {round_num}: score={score}/10, "
            f"issues={len(issues)}, fixes={len(fixes)}"
        )

    # 4. Max rounds reached — escalate to user
    summary, options = build_escalation_summary(rounds, model_name)
    logger.warning(f"[Debate] ESCALATING to user after {max_rounds} rounds")

    if user_callback:
        # Interactive mode — ask user
        user_choice = await user_callback(summary, options)
        return DebateResult(
            outcome=DebateOutcome.USER_OVERRIDE,
            final_score=rounds[-1].gemini_score if rounds else 0,
            rounds=rounds,
            summary=summary,
            user_options=options,
            user_choice=user_choice.get("id", "accept_current"),
        )
    else:
        # Non-interactive — return escalation for later handling
        return DebateResult(
            outcome=DebateOutcome.ESCALATED,
            final_score=rounds[-1].gemini_score if rounds else 0,
            rounds=rounds,
            summary=summary,
            user_options=options,
        )
