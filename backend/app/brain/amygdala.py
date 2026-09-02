"""
Amygdala — The brain's survival center and load-shedding protocol.

Monitors system resources (CPU, memory, request rate) and triggers
emergency "Survival Mode" when thresholds are breached. During survival:
    - Non-critical tools are disabled
    - SEAL loop frequency is reduced
    - All resources are redirected to critical features
    - Automatic recovery when metrics stabilize
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Optional

import psutil

from app.brain.models.schemas import BrainEvent, EventType, Severity, SystemState
from app.brain.mythos import OpenMythos
from app.brain.tools.registry import ToolRegistry
from app.config import Settings

logger = logging.getLogger("gci.amygdala")


class Amygdala:
    """
    The survival center of the GCI brain.

    Monitors system vitals and autonomously activates/deactivates
    survival mode to prevent crashes during extreme load.
    """

    def __init__(
        self,
        settings: Settings,
        mythos: OpenMythos,
        tool_registry: ToolRegistry,
    ) -> None:
        self._settings = settings
        self._mythos = mythos
        self._tools = tool_registry
        self._survival_mode = False
        self._survival_entered_at: Optional[float] = None
        self._safe_since: Optional[float] = None  # Track when metrics became safe
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self._start_time = time.time()

        # Request rate tracking
        self._request_timestamps: list[float] = []

    # ── Lifecycle ────────────────────────────────────────────────────

    async def start(self) -> None:
        """Start the Amygdala monitoring loop."""
        if self._running:
            logger.warning("Amygdala is already running.")
            return

        self._running = True
        self._task = asyncio.create_task(self._monitor_loop())
        logger.info(
            f"Amygdala started. Thresholds — "
            f"CPU: {self._settings.amygdala_cpu_threshold}%, "
            f"Memory: {self._settings.amygdala_memory_threshold}%, "
            f"Requests/min: {self._settings.amygdala_request_rate_threshold}"
        )

    async def stop(self) -> None:
        """Stop the Amygdala monitoring loop."""
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("Amygdala stopped.")

    # ── Monitoring Loop ──────────────────────────────────────────────

    async def _monitor_loop(self) -> None:
        """Continuous monitoring loop."""
        while self._running:
            try:
                state = self.check_vitals()

                if self._survival_mode:
                    await self._check_recovery(state)
                else:
                    await self._check_threats(state)

            except Exception as e:
                logger.error(f"Amygdala monitoring error: {e}", exc_info=True)

            await asyncio.sleep(self._settings.amygdala_check_interval_seconds)

    # ── Vital Signs ──────────────────────────────────────────────────

    def check_vitals(self) -> SystemState:
        """Take a snapshot of current system resource usage."""
        cpu = psutil.cpu_percent(interval=0.3)
        memory = psutil.virtual_memory().percent
        disk = psutil.disk_usage("/").percent
        rpm = self._calculate_rpm()

        return SystemState(
            cpu_percent=cpu,
            memory_percent=memory,
            disk_percent=disk,
            requests_per_minute=rpm,
            survival_mode=self._survival_mode,
            uptime_seconds=round(time.time() - self._start_time, 1),
            active_tools=self._tools.active_count,
            disabled_tools=self._tools.disabled_count,
        )

    def record_request(self) -> None:
        """
        Record an incoming request timestamp for RPM calculation.
        Called by the FastAPI middleware.
        """
        now = time.time()
        self._request_timestamps.append(now)
        # Keep only last 60 seconds of timestamps
        cutoff = now - 60
        self._request_timestamps = [
            t for t in self._request_timestamps if t > cutoff
        ]

    def _calculate_rpm(self) -> float:
        """Calculate requests per minute from recent timestamps."""
        now = time.time()
        cutoff = now - 60
        recent = [t for t in self._request_timestamps if t > cutoff]
        return float(len(recent))

    # ── Threat Detection ─────────────────────────────────────────────

    async def _check_threats(self, state: SystemState) -> None:
        """Check if any threshold is breached and enter survival mode."""
        threats: list[str] = []

        if state.cpu_percent > self._settings.amygdala_cpu_threshold:
            threats.append(f"CPU: {state.cpu_percent}%")

        if state.memory_percent > self._settings.amygdala_memory_threshold:
            threats.append(f"Memory: {state.memory_percent}%")

        if state.requests_per_minute > self._settings.amygdala_request_rate_threshold:
            threats.append(f"RPM: {state.requests_per_minute}")

        if threats:
            logger.critical(
                f"Amygdala: Threshold breached! {', '.join(threats)}. "
                f"Entering survival mode."
            )
            await self.enter_survival_mode(reason=", ".join(threats))

    async def _check_recovery(self, state: SystemState) -> None:
        """
        Check if all metrics are safe and have been safe long enough
        to exit survival mode.
        """
        is_safe = (
            state.cpu_percent < self._settings.amygdala_cpu_threshold * 0.8
            and state.memory_percent < self._settings.amygdala_memory_threshold * 0.8
            and state.requests_per_minute < self._settings.amygdala_request_rate_threshold * 0.8
        )

        if is_safe:
            if self._safe_since is None:
                self._safe_since = time.time()
                logger.info("Amygdala: Metrics returning to safe levels...")
            else:
                safe_duration = time.time() - self._safe_since
                if safe_duration >= self._settings.amygdala_cooldown_seconds:
                    await self.exit_survival_mode()
        else:
            # Reset the safe counter if metrics spike again
            self._safe_since = None

    # ── Survival Mode ────────────────────────────────────────────────

    async def enter_survival_mode(self, reason: str = "Unknown") -> None:
        """
        Activate survival mode:
        1. Disable all non-critical tools
        2. Log CRITICAL event
        3. Alert (production: push notification / Slack webhook)
        """
        if self._survival_mode:
            return  # Already in survival mode

        self._survival_mode = True
        self._survival_entered_at = time.time()
        self._safe_since = None

        # Disable non-critical tools
        disabled = self._tools.enter_survival_mode()

        self._mythos.log_event(BrainEvent(
            event_type=EventType.SURVIVAL_ENTER,
            severity=Severity.CRITICAL,
            source="amygdala",
            message=(
                f"SURVIVAL MODE ACTIVATED. Reason: {reason}. "
                f"Disabled {len(disabled)} non-critical tools: {disabled}"
            ),
            data={
                "reason": reason,
                "disabled_tools": disabled,
            },
        ))

        self._mythos.remember(
            text=(
                f"Survival mode was activated due to: {reason}. "
                f"Disabled {len(disabled)} tools. "
                f"System was under extreme load."
            ),
            source="amygdala",
            memory_type="anomaly",
        )

        logger.critical(
            f"🚨 SURVIVAL MODE ON — Reason: {reason}. "
            f"Disabled {len(disabled)} tools."
        )

    async def exit_survival_mode(self) -> None:
        """
        Deactivate survival mode:
        1. Re-enable all tools
        2. Log RECOVERY event
        """
        if not self._survival_mode:
            return

        self._survival_mode = False
        duration = (
            time.time() - self._survival_entered_at
            if self._survival_entered_at else 0
        )
        self._survival_entered_at = None
        self._safe_since = None

        # Re-enable all tools
        re_enabled = self._tools.exit_survival_mode()

        self._mythos.log_event(BrainEvent(
            event_type=EventType.SURVIVAL_EXIT,
            severity=Severity.INFO,
            source="amygdala",
            message=(
                f"SURVIVAL MODE DEACTIVATED after {duration:.0f}s. "
                f"Re-enabled {len(re_enabled)} tools: {re_enabled}"
            ),
            data={
                "duration_seconds": round(duration, 1),
                "re_enabled_tools": re_enabled,
            },
        ))

        self._mythos.remember(
            text=(
                f"Survival mode ended after {duration:.0f} seconds. "
                f"Re-enabled {len(re_enabled)} tools. System recovered."
            ),
            source="amygdala",
            memory_type="anomaly",
        )

        logger.info(
            f"✅ SURVIVAL MODE OFF — Duration: {duration:.0f}s. "
            f"Re-enabled {len(re_enabled)} tools."
        )

    # ── Properties ───────────────────────────────────────────────────

    @property
    def is_survival_active(self) -> bool:
        return self._survival_mode

    @property
    def survival_duration(self) -> Optional[float]:
        """Seconds since survival mode was entered, or None."""
        if self._survival_mode and self._survival_entered_at:
            return time.time() - self._survival_entered_at
        return None
