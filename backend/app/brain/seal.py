"""
SEAL Loop — Sense → Evaluate → Act → Learn.

The operational heartbeat of the GCI brain. Runs as a continuous
background async loop on a configurable interval.

Each cycle:
    1. SENSE: Collect telemetry (system health, recent events, API status)
    2. EVALUATE: Feed sensed data to the LLM for anomaly classification
    3. ACT: Execute appropriate tools based on the LLM's verdict
    4. LEARN: Record the full cycle outcome into the Open Mythos
"""

from __future__ import annotations

import asyncio
import logging
import time
import uuid
from typing import Any, Callable, Optional

from app.brain.models.schemas import (
    Anomaly,
    BrainEvent,
    EventType,
    SEALCycleResult,
    Severity,
)
from app.brain.mythos import OpenMythos
from app.brain.tools.registry import ToolRegistry
from app.config import Settings

logger = logging.getLogger("gci.seal")


class SEALLoop:
    """
    The SEAL (Sense-Evaluate-Act-Learn) continuous loop.

    This is the brain's heartbeat. It monitors the system, detects
    anomalies, takes corrective action, and learns from outcomes.
    """

    def __init__(
        self,
        settings: Settings,
        mythos: OpenMythos,
        tool_registry: ToolRegistry,
        llm_invoke: Optional[Callable] = None,
        amygdala_trigger: Optional[Callable] = None,
    ) -> None:
        self._settings = settings
        self._mythos = mythos
        self._tools = tool_registry
        self._llm_invoke = llm_invoke  # Injected by core.py
        self._amygdala_trigger = amygdala_trigger  # Callback to trigger survival mode
        self._running = False
        self._paused = False
        self._task: Optional[asyncio.Task] = None
        self._cycle_count = 0
        self._last_cycle: Optional[SEALCycleResult] = None

    # ── Loop Control ─────────────────────────────────────────────────

    async def start(self) -> None:
        """Start the SEAL loop as a background async task."""
        if self._running:
            logger.warning("SEAL loop is already running.")
            return

        self._running = True
        self._paused = False
        self._task = asyncio.create_task(self._loop())
        logger.info(
            f"SEAL loop started. Interval: {self._settings.seal_loop_interval_seconds}s"
        )

        self._mythos.log_event(BrainEvent(
            event_type=EventType.SYSTEM,
            source="seal",
            message="SEAL loop started.",
        ))

    async def stop(self) -> None:
        """Stop the SEAL loop."""
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("SEAL loop stopped.")

        self._mythos.log_event(BrainEvent(
            event_type=EventType.SYSTEM,
            source="seal",
            message="SEAL loop stopped.",
        ))

    def pause(self) -> None:
        """Pause the SEAL loop (skips cycles without stopping the task)."""
        self._paused = True
        logger.info("SEAL loop paused.")

    def resume(self) -> None:
        """Resume a paused SEAL loop."""
        self._paused = False
        logger.info("SEAL loop resumed.")

    @property
    def is_running(self) -> bool:
        return self._running and not self._paused

    @property
    def cycle_count(self) -> int:
        return self._cycle_count

    @property
    def last_cycle(self) -> Optional[SEALCycleResult]:
        return self._last_cycle

    # ── The Main Loop ────────────────────────────────────────────────

    async def _loop(self) -> None:
        """The continuous SEAL loop."""
        while self._running:
            if not self._paused:
                try:
                    await self._run_cycle()
                except Exception as e:
                    logger.error(f"SEAL cycle error: {e}", exc_info=True)
                    self._mythos.log_event(BrainEvent(
                        event_type=EventType.ERROR,
                        severity=Severity.WARNING,
                        source="seal",
                        message=f"SEAL cycle failed: {str(e)}",
                    ))

            await asyncio.sleep(self._settings.seal_loop_interval_seconds)

    async def _run_cycle(self) -> SEALCycleResult:
        """Execute one complete SEAL cycle."""
        cycle_id = f"seal_{uuid.uuid4().hex[:8]}"
        start_time = time.perf_counter()

        logger.debug(f"Starting SEAL cycle {cycle_id}")

        # ── 1. SENSE ─────────────────────────────────────────────
        sensed_data = await self._sense()

        self._mythos.log_event(BrainEvent(
            event_type=EventType.SENSE,
            source="seal",
            message=f"Cycle {cycle_id}: Sensed system telemetry.",
            data={"cycle_id": cycle_id, "metrics": sensed_data},
        ))

        # ── 2. EVALUATE ──────────────────────────────────────────
        anomalies = await self._evaluate(sensed_data)

        self._mythos.log_event(BrainEvent(
            event_type=EventType.EVALUATE,
            severity=self._max_severity(anomalies),
            source="seal",
            message=(
                f"Cycle {cycle_id}: Evaluated. "
                f"Found {len(anomalies)} anomalies."
            ),
            data={
                "cycle_id": cycle_id,
                "anomalies": [a.model_dump() for a in anomalies],
            },
        ))

        # ── 3. ACT ───────────────────────────────────────────────
        actions_taken = await self._act(anomalies)

        for action in actions_taken:
            self._mythos.log_event(BrainEvent(
                event_type=EventType.ACT,
                source="seal",
                message=f"Cycle {cycle_id}: {action}",
                data={"cycle_id": cycle_id},
            ))

        # ── 4. LEARN ─────────────────────────────────────────────
        duration_ms = (time.perf_counter() - start_time) * 1000
        lessons = self._learn(cycle_id, sensed_data, anomalies, actions_taken)

        result = SEALCycleResult(
            cycle_id=cycle_id,
            sensed_data=sensed_data,
            anomalies=anomalies,
            actions_taken=actions_taken,
            lessons_learned=lessons,
            duration_ms=round(duration_ms, 2),
        )

        self._last_cycle = result
        self._cycle_count += 1

        self._mythos.log_event(BrainEvent(
            event_type=EventType.LEARN,
            source="seal",
            message=(
                f"Cycle {cycle_id} complete in {result.duration_ms}ms. "
                f"Anomalies: {len(anomalies)}, Actions: {len(actions_taken)}"
            ),
            data={"cycle_id": cycle_id, "lessons": lessons},
        ))

        logger.info(
            f"SEAL cycle {cycle_id} complete: "
            f"{len(anomalies)} anomalies, {len(actions_taken)} actions, "
            f"{result.duration_ms}ms"
        )

        return result

    # ── Phase Implementations ────────────────────────────────────────

    async def _sense(self) -> dict[str, Any]:
        """
        SENSE phase: Collect telemetry from all available sources.
        """
        telemetry: dict[str, Any] = {}

        # Run the health_check tool if available
        health_tool = self._tools.get_tool("health_check")
        if health_tool and self._tools.is_tool_active("health_check"):
            record = await health_tool.safe_execute()
            self._mythos.log_tool_call(record)
            telemetry["system_health"] = record.output_data or {}

        # Get recent errors from the Mythos
        recent_errors = self._mythos.get_recent_events(
            event_type=EventType.ERROR,
            limit=10,
        )
        telemetry["recent_errors"] = [
            {"message": e.message, "source": e.source, "severity": e.severity.value}
            for e in recent_errors
        ]
        telemetry["error_count_24h"] = self._mythos.get_error_count(since_hours=24)

        # Get recent tool failures
        recent_tools = self._mythos.get_tool_history(limit=20)
        failed_tools = [t for t in recent_tools if t.status.value != "SUCCESS"]
        telemetry["recent_tool_failures"] = [
            {"tool": t.tool_name, "error": t.error_message, "status": t.status.value}
            for t in failed_tools[:5]
        ]

        return telemetry

    async def _evaluate(self, sensed_data: dict[str, Any]) -> list[Anomaly]:
        """
        EVALUATE phase: Analyze sensed data for anomalies.

        If LLM is available, uses it for intelligent evaluation.
        Otherwise, falls back to rule-based checks.
        """
        anomalies: list[Anomaly] = []

        # Rule-based evaluation (always runs, LLM-independent)
        health = sensed_data.get("system_health", {})

        cpu = health.get("cpu_percent", 0)
        memory = health.get("memory_percent", 0)
        disk = health.get("disk_percent", 0)

        if cpu > self._settings.amygdala_cpu_threshold:
            anomalies.append(Anomaly(
                description=f"CPU usage critically high: {cpu}%",
                severity=Severity.CRITICAL,
                source="system",
                suggested_action="Trigger Amygdala survival mode",
            ))
        elif cpu > 70:
            anomalies.append(Anomaly(
                description=f"CPU usage elevated: {cpu}%",
                severity=Severity.WARNING,
                source="system",
                suggested_action="Monitor closely",
            ))

        if memory > self._settings.amygdala_memory_threshold:
            anomalies.append(Anomaly(
                description=f"Memory usage critically high: {memory}%",
                severity=Severity.CRITICAL,
                source="system",
                suggested_action="Trigger Amygdala survival mode",
            ))

        if disk > 90:
            anomalies.append(Anomaly(
                description=f"Disk usage high: {disk}%",
                severity=Severity.WARNING,
                source="system",
                suggested_action="Run Dreamer cleanup early",
            ))

        # Check for elevated error rates
        error_count = sensed_data.get("error_count_24h", 0)
        if error_count > 50:
            anomalies.append(Anomaly(
                description=f"High error rate: {error_count} errors in last 24h",
                severity=Severity.WARNING,
                source="events",
                suggested_action="Run log_analyzer for clustering",
                tool_to_use="log_analyzer",
            ))

        # Check for tool failures
        tool_failures = sensed_data.get("recent_tool_failures", [])
        if len(tool_failures) > 3:
            failing_tools = set(t["tool"] for t in tool_failures)
            anomalies.append(Anomaly(
                description=f"Multiple tool failures detected: {failing_tools}",
                severity=Severity.WARNING,
                source="tools",
                suggested_action="Investigate failing tools",
            ))

        # LLM-enhanced evaluation (if available)
        if self._llm_invoke and anomalies:
            try:
                llm_analysis = await self._llm_evaluate(sensed_data, anomalies)
                if llm_analysis:
                    anomalies.extend(llm_analysis)
            except Exception as e:
                logger.warning(f"LLM evaluation failed (falling back to rules): {e}")

        return anomalies

    async def _llm_evaluate(
        self,
        sensed_data: dict[str, Any],
        rule_anomalies: list[Anomaly],
    ) -> list[Anomaly]:
        """
        Use the LLM for deeper anomaly analysis beyond simple threshold checks.
        """
        if not self._llm_invoke:
            return []

        prompt = (
            "You are the GCI brain's SEAL evaluator. Analyze the following "
            "system telemetry and the rule-based anomalies already detected. "
            "Identify any ADDITIONAL anomalies or patterns the rules may "
            "have missed. Return ONLY new anomalies not already listed.\n\n"
            f"Telemetry: {sensed_data}\n\n"
            f"Already detected: {[a.description for a in rule_anomalies]}\n\n"
            "Respond with a JSON array of objects with keys: "
            "description, severity (CRITICAL/WARNING/INFO), source, suggested_action. "
            "If no new anomalies, respond with an empty array []."
        )

        try:
            response = await self._llm_invoke(prompt)
            # Parse LLM response — the core.py handles actual LLM calls
            # For now, return empty (LLM integration is in core.py)
            return []
        except Exception:
            return []

    async def _act(self, anomalies: list[Anomaly]) -> list[str]:
        """
        ACT phase: Take corrective action for each detected anomaly.
        """
        actions: list[str] = []

        for anomaly in anomalies:
            if anomaly.severity == Severity.CRITICAL:
                # Trigger Amygdala survival mode
                if self._amygdala_trigger:
                    await self._amygdala_trigger()
                    actions.append(
                        f"Triggered Amygdala survival mode for: {anomaly.description}"
                    )
                else:
                    actions.append(
                        f"CRITICAL anomaly detected but no Amygdala configured: "
                        f"{anomaly.description}"
                    )

            elif anomaly.tool_to_use:
                # Execute the suggested tool
                tool = self._tools.get_tool(anomaly.tool_to_use)
                if tool and self._tools.is_tool_active(anomaly.tool_to_use):
                    record = await tool.safe_execute()
                    self._mythos.log_tool_call(record)
                    actions.append(
                        f"Executed tool '{anomaly.tool_to_use}' for: "
                        f"{anomaly.description}"
                    )
                else:
                    actions.append(
                        f"Tool '{anomaly.tool_to_use}' not available for: "
                        f"{anomaly.description}"
                    )
            else:
                # Log as info for future reference
                actions.append(f"Logged anomaly: {anomaly.description}")

        return actions

    def _learn(
        self,
        cycle_id: str,
        sensed_data: dict[str, Any],
        anomalies: list[Anomaly],
        actions: list[str],
    ) -> list[str]:
        """
        LEARN phase: Record the cycle outcome into the Mythos.
        The brain remembers what happened so it never repeats mistakes.
        """
        lessons: list[str] = []

        if not anomalies:
            lessons.append("System is healthy. No anomalies detected.")
        else:
            for anomaly in anomalies:
                lesson = (
                    f"Detected {anomaly.severity.value} anomaly in "
                    f"{anomaly.source}: {anomaly.description}"
                )
                lessons.append(lesson)

        # Store the cycle summary in semantic memory
        summary = (
            f"SEAL Cycle {cycle_id}: "
            f"Sensed {len(sensed_data)} data points, "
            f"found {len(anomalies)} anomalies, "
            f"took {len(actions)} actions. "
            f"Lessons: {'; '.join(lessons)}"
        )

        self._mythos.remember(
            text=summary,
            source="seal",
            memory_type="seal_cycle",
            metadata={
                "cycle_id": cycle_id,
                "anomaly_count": len(anomalies),
                "action_count": len(actions),
            },
        )

        return lessons

    def _max_severity(self, anomalies: list[Anomaly]) -> Severity:
        """Get the highest severity from a list of anomalies."""
        if not anomalies:
            return Severity.INFO
        severity_order = {Severity.CRITICAL: 3, Severity.WARNING: 2, Severity.INFO: 1}
        return max(anomalies, key=lambda a: severity_order.get(a.severity, 0)).severity

    # ── Manual Trigger ───────────────────────────────────────────────

    async def run_once(self) -> SEALCycleResult:
        """Manually trigger a single SEAL cycle (useful for testing)."""
        return await self._run_cycle()
