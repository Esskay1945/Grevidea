"""
GCI Tool Registry — Discovers, registers, and manages all tools available to the brain.

The registry is the "toolbox" sitting on the CEO's desk. The LLM Orchestrator
queries it to know what tools exist, their schemas, and which are active.
During Amygdala survival mode, non-critical tools are disabled.
"""

from __future__ import annotations

import importlib
import inspect
import logging
import pkgutil
from pathlib import Path
from typing import Any, Optional

from app.brain.tools.base import BaseTool

logger = logging.getLogger("gci.tools.registry")


class ToolRegistry:
    """
    Central registry for all GCI tools.

    Supports:
        - Manual registration via register()
        - Auto-discovery of tools in the builtin/ directory
        - Enabling/disabling tools for survival mode
        - Exporting tool schemas for LLM function calling
    """

    def __init__(self) -> None:
        self._tools: dict[str, BaseTool] = {}
        self._disabled: set[str] = set()

    def register(self, tool: BaseTool) -> None:
        """Register a tool instance. Overwrites if name already exists."""
        if tool.name in self._tools:
            logger.warning(f"Tool '{tool.name}' already registered. Overwriting.")
        self._tools[tool.name] = tool
        logger.info(f"Registered tool: {tool.name} (critical={tool.is_critical})")

    def unregister(self, name: str) -> None:
        """Remove a tool from the registry."""
        if name in self._tools:
            del self._tools[name]
            self._disabled.discard(name)
            logger.info(f"Unregistered tool: {name}")

    def get_tool(self, name: str) -> Optional[BaseTool]:
        """Retrieve a tool by name. Returns None if not found."""
        return self._tools.get(name)

    def list_tools(self) -> list[dict[str, Any]]:
        """Return all registered tools with their metadata."""
        return [
            {
                "name": tool.name,
                "description": tool.description,
                "is_critical": tool.is_critical,
                "is_active": tool.name not in self._disabled,
                "parameters": tool.parameters,
            }
            for tool in self._tools.values()
        ]

    def get_active_tools(self) -> list[BaseTool]:
        """Return only tools that are currently enabled (not disabled by Amygdala)."""
        return [
            tool for name, tool in self._tools.items()
            if name not in self._disabled
        ]

    def get_critical_tools(self) -> list[BaseTool]:
        """Return only survival-essential tools (is_critical=True)."""
        return [tool for tool in self._tools.values() if tool.is_critical]

    def get_active_tool_schemas(self) -> list[dict[str, Any]]:
        """
        Export LangChain-compatible schemas for all active tools.
        Used to build the LLM's function calling context.
        """
        return [tool.to_langchain_schema() for tool in self.get_active_tools()]

    # ── Survival Mode (Amygdala Integration) ─────────────────────────

    def enter_survival_mode(self) -> list[str]:
        """
        Disable all non-critical tools. Called by the Amygdala.
        Returns list of tool names that were disabled.
        """
        newly_disabled = []
        for name, tool in self._tools.items():
            if not tool.is_critical and name not in self._disabled:
                self._disabled.add(name)
                newly_disabled.append(name)
        logger.warning(
            f"Survival mode: disabled {len(newly_disabled)} non-critical tools: "
            f"{newly_disabled}"
        )
        return newly_disabled

    def exit_survival_mode(self) -> list[str]:
        """
        Re-enable all tools. Called by the Amygdala on recovery.
        Returns list of tool names that were re-enabled.
        """
        re_enabled = list(self._disabled)
        self._disabled.clear()
        logger.info(
            f"Survival mode ended: re-enabled {len(re_enabled)} tools: {re_enabled}"
        )
        return re_enabled

    def is_tool_active(self, name: str) -> bool:
        """Check if a specific tool is currently active."""
        return name in self._tools and name not in self._disabled

    # ── Auto-Discovery ───────────────────────────────────────────────

    def auto_discover(self, package_name: str = "app.brain.tools.builtin") -> int:
        """
        Scan the builtin tools package and auto-register all BaseTool subclasses.

        Returns the number of tools discovered and registered.
        """
        count = 0
        try:
            package = importlib.import_module(package_name)
            package_path = Path(package.__file__).parent

            for _, module_name, _ in pkgutil.iter_modules([str(package_path)]):
                full_module_name = f"{package_name}.{module_name}"
                try:
                    module = importlib.import_module(full_module_name)
                    for attr_name in dir(module):
                        attr = getattr(module, attr_name)
                        if (
                            inspect.isclass(attr)
                            and issubclass(attr, BaseTool)
                            and attr is not BaseTool
                        ):
                            tool_instance = attr()
                            if tool_instance.name:
                                self.register(tool_instance)
                                count += 1
                except Exception as e:
                    logger.error(
                        f"Failed to load tool module '{full_module_name}': {e}"
                    )
        except Exception as e:
            logger.error(f"Failed to discover tools in '{package_name}': {e}")

        logger.info(f"Auto-discovery complete: {count} tools registered.")
        return count

    # ── Stats ────────────────────────────────────────────────────────

    @property
    def total_count(self) -> int:
        """Total number of registered tools."""
        return len(self._tools)

    @property
    def active_count(self) -> int:
        """Number of currently active (enabled) tools."""
        return len(self._tools) - len(self._disabled)

    @property
    def disabled_count(self) -> int:
        """Number of currently disabled tools."""
        return len(self._disabled)

    def __repr__(self) -> str:
        return (
            f"<ToolRegistry: {self.total_count} tools, "
            f"{self.active_count} active, "
            f"{self.disabled_count} disabled>"
        )
