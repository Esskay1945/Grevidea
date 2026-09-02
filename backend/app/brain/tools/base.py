"""
GCI Tool Base — Abstract base class for all tools the brain can use.

Every tool in Grevidea is a deterministic Python function that the brain's
LLM Orchestrator can pick up, use, and put down. Tools do the actual work;
the LLM only decides *which* tool to call and with *what* input.
"""

from __future__ import annotations

import time
from abc import ABC, abstractmethod
from typing import Any

from app.brain.models.schemas import ToolCallRecord, ToolStatus


class BaseTool(ABC):
    """
    Abstract base class for all GCI tools.

    Every tool must define:
        - name: Unique identifier (e.g., "health_check")
        - description: What this tool does (fed to the LLM for tool selection)
        - parameters: JSON Schema of expected inputs
        - is_critical: Whether this tool remains active during Amygdala survival mode
        - execute(): The deterministic function that does the actual work
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Unique tool identifier."""
        ...

    @property
    @abstractmethod
    def description(self) -> str:
        """Human-readable description of what this tool does. Fed to the LLM."""
        ...

    @property
    def parameters(self) -> dict[str, Any]:
        """
        JSON Schema defining the tool's expected input parameters.
        Override in subclasses to define specific inputs.
        Default: no parameters required.
        """
        return {
            "type": "object",
            "properties": {},
            "required": [],
        }

    @property
    def is_critical(self) -> bool:
        """
        Whether this tool stays active during Amygdala survival mode.
        Override to True for essential system tools.
        Default: False (non-critical, disabled during survival).
        """
        return False

    @abstractmethod
    async def execute(self, **kwargs: Any) -> dict[str, Any]:
        """
        Execute the tool with the given inputs.

        Args:
            **kwargs: Tool-specific input parameters matching the JSON Schema.

        Returns:
            A dictionary containing the tool's output.

        Raises:
            Exception: If the tool encounters an error during execution.
        """
        ...

    async def safe_execute(self, **kwargs: Any) -> ToolCallRecord:
        """
        Wrapper that executes the tool and returns a full audit record.
        Catches exceptions and records timing. Used by the brain orchestrator.
        """
        start = time.perf_counter()
        try:
            result = await self.execute(**kwargs)
            duration = (time.perf_counter() - start) * 1000
            return ToolCallRecord(
                tool_name=self.name,
                input_data=kwargs,
                output_data=result,
                status=ToolStatus.SUCCESS,
                duration_ms=round(duration, 2),
            )
        except TimeoutError:
            duration = (time.perf_counter() - start) * 1000
            return ToolCallRecord(
                tool_name=self.name,
                input_data=kwargs,
                status=ToolStatus.TIMEOUT,
                duration_ms=round(duration, 2),
                error_message="Tool execution timed out",
            )
        except Exception as e:
            duration = (time.perf_counter() - start) * 1000
            return ToolCallRecord(
                tool_name=self.name,
                input_data=kwargs,
                status=ToolStatus.FAILURE,
                duration_ms=round(duration, 2),
                error_message=str(e),
            )

    def to_langchain_schema(self) -> dict[str, Any]:
        """
        Convert this tool's definition into a LangChain-compatible
        function/tool schema for LLM function calling.
        """
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters,
            },
        }

    def __repr__(self) -> str:
        return f"<Tool: {self.name} (critical={self.is_critical})>"
