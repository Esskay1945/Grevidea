"""
Log Analyzer Tool — Reads recent errors, clusters them, and returns a summary.

Used by the SEAL loop during the "Evaluate" phase to understand
what's going wrong in the system without the LLM having to process
every individual log entry.
"""

from __future__ import annotations

from collections import Counter
from typing import Any

from app.brain.tools.base import BaseTool


class LogAnalyzerTool(BaseTool):
    """
    Analyzes recent error events from the brain's event log,
    clusters them by source and type, and returns a structured summary.
    """

    @property
    def name(self) -> str:
        return "log_analyzer"

    @property
    def description(self) -> str:
        return (
            "Analyzes recent error events from the brain's event log. "
            "Clusters errors by source and message pattern, counts occurrences, "
            "and identifies the most frequent failure points. Use this tool "
            "to get a quick overview of what's going wrong in the system."
        )

    @property
    def parameters(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "hours": {
                    "type": "integer",
                    "description": "How many hours back to analyze (default: 24).",
                    "default": 24,
                },
                "include_warnings": {
                    "type": "boolean",
                    "description": "Whether to include WARNING-level events (default: False).",
                    "default": False,
                },
            },
            "required": [],
        }

    @property
    def is_critical(self) -> bool:
        return False  # Not essential during survival mode

    async def execute(self, **kwargs: Any) -> dict[str, Any]:
        hours = kwargs.get("hours", 24)
        include_warnings = kwargs.get("include_warnings", False)

        # This tool returns an analysis descriptor. The brain core
        # will fetch the actual events from the Mythos and pass them
        # through this analysis logic.
        return {
            "analysis_request": {
                "type": "error_clustering",
                "hours": hours,
                "include_warnings": include_warnings,
            },
            "note": (
                "The brain core will fetch events from the Mythos, "
                "run the clustering analysis, and return the results."
            ),
        }


def analyze_events(events: list[dict[str, Any]]) -> dict[str, Any]:
    """
    Pure analysis function that clusters error events.

    Args:
        events: List of event dicts with 'source', 'message', 'severity' keys.

    Returns:
        Structured analysis summary.
    """
    if not events:
        return {
            "total_errors": 0,
            "clusters": [],
            "most_affected_source": None,
            "summary": "No errors found in the specified time window.",
        }

    # Cluster by source
    source_counter = Counter(e.get("source", "unknown") for e in events)

    # Cluster by message pattern (first 50 chars as rough grouping)
    pattern_counter = Counter(
        e.get("message", "")[:50] for e in events
    )

    # Build clusters
    clusters = []
    for pattern, count in pattern_counter.most_common(10):
        matching = [e for e in events if e.get("message", "").startswith(pattern)]
        clusters.append({
            "pattern": pattern,
            "count": count,
            "sources": list(set(e.get("source", "unknown") for e in matching)),
            "severities": list(set(e.get("severity", "ERROR") for e in matching)),
            "latest": max(
                (e.get("timestamp", "") for e in matching),
                default="",
            ),
        })

    most_affected = source_counter.most_common(1)

    return {
        "total_errors": len(events),
        "unique_sources": len(source_counter),
        "clusters": clusters,
        "source_breakdown": dict(source_counter.most_common()),
        "most_affected_source": most_affected[0][0] if most_affected else None,
        "summary": (
            f"Found {len(events)} errors across {len(source_counter)} sources. "
            f"Most affected: {most_affected[0][0] if most_affected else 'N/A'} "
            f"({most_affected[0][1] if most_affected else 0} errors)."
        ),
    }
