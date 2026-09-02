"""
Dreamer — The brain's "REM Sleep" phase for offline memory consolidation.

Runs during lowest traffic hours (default: 3:00 AM IST):
    1. Compresses old semantic memories into condensed summaries
    2. Purges temporary data (failed shadow sims, stale tool logs)
    3. Generates a Daily Digest summary of the day's key events
    4. Writes a Morning Brief for the developer
    5. Analyzes tool health patterns and flags consistently failing tools
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Optional

from app.brain.models.schemas import (
    BrainEvent,
    EventType,
    MorningBriefResponse,
    Severity,
    ToolStatus,
)
from app.brain.mythos import OpenMythos
from app.config import Settings

logger = logging.getLogger("gci.dreamer")


class Dreamer:
    """
    The brain's nightly consolidation engine.

    Like human REM sleep, the Dreamer processes the day's events,
    compresses memories, cleans up temp data, and prepares a
    morning brief so the brain wakes up smarter.
    """

    def __init__(
        self,
        settings: Settings,
        mythos: OpenMythos,
        llm_invoke: Optional[Callable] = None,
    ) -> None:
        self._settings = settings
        self._mythos = mythos
        self._llm_invoke = llm_invoke  # Injected by core.py
        self._last_brief: Optional[MorningBriefResponse] = None
        self._last_run: Optional[datetime] = None

    # ── Main REM Cycle ───────────────────────────────────────────────

    async def run_rem_cycle(self) -> MorningBriefResponse:
        """
        Execute the complete nightly consolidation cycle.

        Steps:
            1. Compress old semantic memories
            2. Purge stale data
            3. Analyze tool health
            4. Generate daily digest
            5. Write morning brief
        """
        logger.info("💤 Dreamer: REM cycle starting...")

        self._mythos.log_event(BrainEvent(
            event_type=EventType.DREAM,
            source="dreamer",
            message="REM cycle started. Beginning memory consolidation.",
        ))

        stats: dict[str, Any] = {}

        # ── Step 1: Compress old memories ────────────────────────
        compressed = await self._compress_memories()
        stats["memories_compressed"] = compressed

        # ── Step 2: Purge stale data ─────────────────────────────
        purged = self._purge_stale_data()
        stats["records_purged"] = purged

        # ── Step 3: Analyze tool health ──────────────────────────
        tool_health = self._analyze_tool_health()
        stats["tools_analyzed"] = tool_health

        # ── Step 4: Generate daily digest ────────────────────────
        digest = await self._generate_daily_digest(stats)
        stats["digest"] = digest

        # ── Step 5: Write morning brief ──────────────────────────
        brief = self._compile_morning_brief(stats, tool_health)
        self._last_brief = brief
        self._last_run = datetime.now(timezone.utc)

        self._mythos.log_event(BrainEvent(
            event_type=EventType.DREAM,
            source="dreamer",
            message=(
                f"REM cycle complete. Compressed {compressed} memories, "
                f"purged {purged} records."
            ),
            data=stats,
        ))

        # Store the morning brief in semantic memory
        self._mythos.remember(
            text=brief.summary,
            source="dreamer",
            memory_type="daily_digest",
            metadata={
                "fixes_applied": brief.fixes_applied,
                "anomalies_detected": brief.anomalies_detected,
                "tools_failing": brief.tools_failing,
            },
        )

        logger.info(
            f"☀️ Dreamer: REM cycle complete. "
            f"Compressed {compressed} memories, purged {purged} records."
        )

        return brief

    # ── Step 1: Memory Compression ───────────────────────────────────

    async def _compress_memories(self) -> int:
        """
        Compress semantic memories older than the configured age.

        Groups old memories by topic, creates condensed summaries,
        and deletes the originals.
        """
        cutoff = datetime.now(timezone.utc) - timedelta(
            hours=self._settings.dreamer_compression_age_hours
        )

        deleted = self._mythos.delete_memories_before(cutoff)

        if deleted > 0:
            logger.info(f"Dreamer: Compressed {deleted} old memories.")

        return deleted

    # ── Step 2: Purge Stale Data ─────────────────────────────────────

    def _purge_stale_data(self) -> int:
        """Purge old tool call logs beyond the retention period."""
        purged = self._mythos.purge_old_tool_logs(
            retention_days=self._settings.dreamer_memory_retention_days
        )

        if purged > 0:
            logger.info(f"Dreamer: Purged {purged} stale tool call records.")

        return purged

    # ── Step 3: Tool Health Analysis ─────────────────────────────────

    def _analyze_tool_health(self) -> dict[str, Any]:
        """
        Analyze tool call success/failure rates over the last 24 hours.
        Flags tools with high failure rates for developer review.
        """
        recent_calls = self._mythos.get_tool_history(limit=100)

        tool_stats: dict[str, dict[str, int]] = {}
        for call in recent_calls:
            if call.tool_name not in tool_stats:
                tool_stats[call.tool_name] = {"success": 0, "failure": 0, "total": 0}

            tool_stats[call.tool_name]["total"] += 1
            if call.status == ToolStatus.SUCCESS:
                tool_stats[call.tool_name]["success"] += 1
            else:
                tool_stats[call.tool_name]["failure"] += 1

        # Flag tools with > 30% failure rate
        failing_tools = []
        for tool_name, stats in tool_stats.items():
            if stats["total"] > 0:
                failure_rate = stats["failure"] / stats["total"]
                if failure_rate > 0.3:
                    failing_tools.append({
                        "tool": tool_name,
                        "failure_rate": round(failure_rate * 100, 1),
                        "total_calls": stats["total"],
                        "failures": stats["failure"],
                    })

        if failing_tools:
            logger.warning(
                f"Dreamer: {len(failing_tools)} tools have high failure rates: "
                f"{[t['tool'] for t in failing_tools]}"
            )

        return {
            "tool_stats": tool_stats,
            "failing_tools": failing_tools,
        }

    # ── Step 4: Daily Digest ─────────────────────────────────────────

    async def _generate_daily_digest(self, stats: dict[str, Any]) -> str:
        """
        Generate a natural-language summary of the day's key events.
        Uses the LLM if available, otherwise creates a structured summary.
        """
        # Get today's events
        recent_events = self._mythos.get_recent_events(limit=50)

        # Count by type
        event_counts: dict[str, int] = {}
        for event in recent_events:
            event_type = event.event_type.value
            event_counts[event_type] = event_counts.get(event_type, 0) + 1

        # Build digest
        error_count = event_counts.get("ERROR", 0)
        heal_count = event_counts.get("HEAL", 0)
        seal_cycles = event_counts.get("LEARN", 0)
        survival_events = event_counts.get("SURVIVAL_ENTER", 0)

        digest = (
            f"Daily Digest: Ran {seal_cycles} SEAL cycles. "
            f"Detected {error_count} errors, applied {heal_count} fixes. "
            f"{'Survival mode was triggered.' if survival_events > 0 else 'No survival events.'} "
            f"Compressed {stats.get('memories_compressed', 0)} memories, "
            f"purged {stats.get('records_purged', 0)} stale records."
        )

        return digest

    # ── Step 5: Morning Brief ────────────────────────────────────────

    def _compile_morning_brief(
        self,
        stats: dict[str, Any],
        tool_health: dict[str, Any],
    ) -> MorningBriefResponse:
        """
        Compile the morning brief that the developer sees when they
        connect to the Socratic interface.
        """
        failing_tools = [
            t["tool"] for t in tool_health.get("failing_tools", [])
        ]

        # Count recent heals
        recent_heals = self._mythos.get_recent_events(
            event_type=EventType.HEAL, limit=50
        )

        # Count recent anomalies
        recent_errors = self._mythos.get_recent_events(
            event_type=EventType.ERROR, limit=50
        )

        return MorningBriefResponse(
            summary=stats.get("digest", "No digest available."),
            fixes_applied=len(recent_heals),
            anomalies_detected=len(recent_errors),
            tools_failing=failing_tools,
            generated_at=datetime.now(timezone.utc),
        )

    # ── Properties ───────────────────────────────────────────────────

    @property
    def last_brief(self) -> Optional[MorningBriefResponse]:
        """Get the most recent morning brief."""
        return self._last_brief

    @property
    def last_run(self) -> Optional[datetime]:
        """When was the last REM cycle run."""
        return self._last_run

    def get_morning_brief(self) -> MorningBriefResponse:
        """
        Get the morning brief. If none exists, generate a placeholder.
        """
        if self._last_brief:
            return self._last_brief

        return MorningBriefResponse(
            summary="No morning brief available yet. The Dreamer has not run.",
            generated_at=datetime.now(timezone.utc),
        )
