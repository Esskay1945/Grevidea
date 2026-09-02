"""
DB Query Tool — Safe, read-only queries against the brain's event log.

Accepts a natural-language question about system data and translates it
into a safe SQL query against the SQLite event log via predefined query
patterns. Never executes raw user-supplied SQL.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from app.brain.tools.base import BaseTool


class DBQueryTool(BaseTool):
    """
    Query the brain's structured memory (SQLite event log) using
    predefined safe query patterns.
    """

    @property
    def name(self) -> str:
        return "db_query"

    @property
    def description(self) -> str:
        return (
            "Query the brain's event log and tool call history using safe, "
            "predefined queries. Supports: counting events by type, listing "
            "recent errors, checking tool call success rates, and getting "
            "event summaries for a time range. Use this to answer questions "
            "about what happened in the system."
        )

    @property
    def parameters(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "query_type": {
                    "type": "string",
                    "enum": [
                        "count_events",
                        "recent_errors",
                        "tool_success_rate",
                        "event_summary",
                        "recent_tool_calls",
                    ],
                    "description": "The type of predefined query to execute.",
                },
                "event_type": {
                    "type": "string",
                    "description": "Optional filter by event type (SENSE, EVALUATE, ACT, LEARN, ERROR, HEAL, etc.)",
                },
                "tool_name": {
                    "type": "string",
                    "description": "Optional filter by tool name.",
                },
                "hours": {
                    "type": "integer",
                    "description": "Time window in hours (default: 24).",
                    "default": 24,
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of results to return (default: 20).",
                    "default": 20,
                },
            },
            "required": ["query_type"],
        }

    @property
    def is_critical(self) -> bool:
        return True  # Needed for diagnostics during survival mode

    async def execute(self, **kwargs: Any) -> dict[str, Any]:
        # Import here to avoid circular imports; the mythos instance
        # will be injected via the brain core at runtime
        query_type = kwargs.get("query_type", "event_summary")
        hours = kwargs.get("hours", 24)
        limit = kwargs.get("limit", 20)
        event_type = kwargs.get("event_type")
        tool_name = kwargs.get("tool_name")

        # We return structured query descriptors that the brain core
        # executes against the Mythos. This tool defines WHAT to query,
        # the core handles HOW to query (database abstraction).
        return {
            "query_descriptor": {
                "query_type": query_type,
                "filters": {
                    "event_type": event_type,
                    "tool_name": tool_name,
                    "hours": hours,
                    "limit": limit,
                    "since": (
                        datetime.now(timezone.utc) - timedelta(hours=hours)
                    ).isoformat(),
                },
            },
            "note": (
                "This returns a query descriptor. The brain core will "
                "execute it against the Open Mythos and return results."
            ),
        }
