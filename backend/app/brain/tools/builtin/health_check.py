"""
Health Check Tool — Returns current system metrics.

This is a CRITICAL tool: it remains active even during Amygdala survival mode
because the brain needs to monitor system health at all times.
"""

from __future__ import annotations

import platform
import time
from typing import Any

import psutil

from app.brain.tools.base import BaseTool

# Track server start time for uptime calculation
_START_TIME = time.time()


class HealthCheckTool(BaseTool):
    """Returns current system resource usage and uptime."""

    @property
    def name(self) -> str:
        return "health_check"

    @property
    def description(self) -> str:
        return (
            "Returns current system health metrics including CPU usage, "
            "memory usage, disk usage, uptime, and platform information. "
            "Use this tool to diagnose performance issues or check if "
            "the server is under load."
        )

    @property
    def parameters(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "verbose": {
                    "type": "boolean",
                    "description": "If true, include per-CPU and per-disk breakdowns.",
                    "default": False,
                },
            },
            "required": [],
        }

    @property
    def is_critical(self) -> bool:
        return True  # Always active, even in survival mode

    async def execute(self, **kwargs: Any) -> dict[str, Any]:
        verbose = kwargs.get("verbose", False)

        cpu_percent = psutil.cpu_percent(interval=0.5)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage("/")
        uptime = time.time() - _START_TIME

        result = {
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "memory_used_gb": round(memory.used / (1024 ** 3), 2),
            "memory_total_gb": round(memory.total / (1024 ** 3), 2),
            "disk_percent": disk.percent,
            "disk_used_gb": round(disk.used / (1024 ** 3), 2),
            "disk_total_gb": round(disk.total / (1024 ** 3), 2),
            "uptime_seconds": round(uptime, 1),
            "uptime_human": _format_uptime(uptime),
            "platform": platform.platform(),
            "python_version": platform.python_version(),
            "status": _get_status(cpu_percent, memory.percent),
        }

        if verbose:
            result["cpu_per_core"] = psutil.cpu_percent(interval=0.5, percpu=True)
            result["disk_partitions"] = [
                {
                    "device": p.device,
                    "mountpoint": p.mountpoint,
                    "fstype": p.fstype,
                }
                for p in psutil.disk_partitions()
            ]

        return result


def _format_uptime(seconds: float) -> str:
    """Convert seconds to human-readable uptime string."""
    hours, remainder = divmod(int(seconds), 3600)
    minutes, secs = divmod(remainder, 60)
    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    elif minutes > 0:
        return f"{minutes}m {secs}s"
    return f"{secs}s"


def _get_status(cpu: float, memory: float) -> str:
    """Determine overall system health status."""
    if cpu > 90 or memory > 95:
        return "CRITICAL"
    elif cpu > 75 or memory > 85:
        return "WARNING"
    return "HEALTHY"
