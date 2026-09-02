"""
Socratic Interface — The developer-facing conversational interface to GCI.

Two modes:
    1. DIRECT: Developer asks, brain answers using tools and memory.
    2. SOCRATIC: Brain asks clarifying questions back for complex problems.

All conversations are logged to the Mythos for future reference.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Callable, Optional

from app.brain.models.schemas import (
    BrainEvent,
    ChatResponse,
    EventType,
    MemoryEntry,
    Severity,
)
from app.brain.mythos import OpenMythos
from app.brain.tools.registry import ToolRegistry
from app.config import Settings

logger = logging.getLogger("gci.socratic")


class SocraticInterface:
    """
    The developer's conversational interface to the GCI brain.

    Maintains per-session conversation history and decides whether
    to answer directly or switch to Socratic mode based on question
    complexity.
    """

    def __init__(
        self,
        settings: Settings,
        mythos: OpenMythos,
        tool_registry: ToolRegistry,
        llm_invoke: Optional[Callable] = None,
    ) -> None:
        self._settings = settings
        self._mythos = mythos
        self._tools = tool_registry
        self._llm_invoke = llm_invoke  # Injected by core.py
        self._sessions: dict[str, list[dict[str, str]]] = {}

    # ── Main Chat Method ─────────────────────────────────────────────

    async def chat(
        self,
        message: str,
        session_id: Optional[str] = None,
    ) -> ChatResponse:
        """
        Process a developer message and return the brain's response.

        Args:
            message: The developer's message/question.
            session_id: Optional session ID for conversation continuity.

        Returns:
            ChatResponse with the brain's answer, tools used, and mode.
        """
        if not session_id:
            session_id = f"session_{uuid.uuid4().hex[:8]}"

        # Initialize session if new
        if session_id not in self._sessions:
            self._sessions[session_id] = []

        # Add user message to session history
        self._sessions[session_id].append({
            "role": "user",
            "content": message,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

        # Log the incoming message
        self._mythos.log_event(BrainEvent(
            event_type=EventType.SYSTEM,
            source="socratic",
            message=f"Developer message: {message[:100]}...",
            data={"session_id": session_id, "full_message": message},
        ))

        # Recall relevant memories
        memories = self._mythos.recall(message, top_k=5)

        # Determine response strategy
        tools_used: list[str] = []
        mode = "direct"

        # Check for special commands
        response_text = await self._handle_special_commands(message)

        if not response_text:
            if self._llm_invoke:
                # Use LLM for intelligent response
                response_text, tools_used, mode = await self._llm_chat(
                    message, session_id, memories
                )
            else:
                # Fallback: no LLM available, use direct tool dispatch
                response_text, tools_used = await self._direct_dispatch(
                    message, memories
                )

        # Add brain response to session history
        self._sessions[session_id].append({
            "role": "assistant",
            "content": response_text,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

        # Log the conversation to Mythos
        self._mythos.remember(
            text=f"Developer asked: '{message}'. Brain responded: '{response_text[:200]}'",
            source="socratic",
            memory_type="conversation",
            metadata={"session_id": session_id, "mode": mode},
        )

        return ChatResponse(
            response=response_text,
            session_id=session_id,
            tools_used=tools_used,
            memories_recalled=len(memories),
            mode=mode,
        )

    # ── Special Commands ─────────────────────────────────────────────

    async def _handle_special_commands(self, message: str) -> Optional[str]:
        """Handle built-in commands before sending to LLM."""
        msg_lower = message.strip().lower()

        if msg_lower in ("status", "how are you", "health"):
            tool = self._tools.get_tool("health_check")
            if tool:
                record = await tool.safe_execute()
                self._mythos.log_tool_call(record)
                data = record.output_data or {}
                return (
                    f"🟢 System Status: {data.get('status', 'UNKNOWN')}\n"
                    f"  • CPU: {data.get('cpu_percent', '?')}%\n"
                    f"  • Memory: {data.get('memory_percent', '?')}%\n"
                    f"  • Disk: {data.get('disk_percent', '?')}%\n"
                    f"  • Uptime: {data.get('uptime_human', '?')}\n"
                    f"  • Platform: {data.get('platform', '?')}"
                )
            return "Health check tool not available."

        if msg_lower in ("morning brief", "brief", "what happened"):
            # Will be wired to the Dreamer's morning brief
            return None  # Fall through to LLM / dispatch

        if msg_lower in ("tools", "list tools"):
            tools = self._tools.list_tools()
            lines = ["📦 Registered Tools:\n"]
            for t in tools:
                status = "✅" if t["is_active"] else "❌"
                critical = " 🔒" if t["is_critical"] else ""
                lines.append(f"  {status} {t['name']}{critical}: {t['description'][:60]}")
            return "\n".join(lines)

        if msg_lower in ("memories", "memory count"):
            count = self._mythos.get_memory_count()
            event_count = self._mythos.get_event_count()
            return (
                f"🧠 Open Mythos Status:\n"
                f"  • Semantic memories: {count}\n"
                f"  • Structured events: {event_count}"
            )

        return None

    # ── LLM-Powered Chat ─────────────────────────────────────────────

    async def _llm_chat(
        self,
        message: str,
        session_id: str,
        memories: list[MemoryEntry],
    ) -> tuple[str, list[str], str]:
        """
        Use the LLM for an intelligent conversational response.
        Returns (response_text, tools_used, mode).
        """
        # Build context from memories
        memory_context = ""
        if memories:
            memory_context = "\n".join([
                f"- [{m.memory_type}] {m.text}" for m in memories
            ])

        # Build conversation history
        history = self._sessions.get(session_id, [])[-10:]  # Last 10 messages

        system_prompt = (
            "You are GCI (Grevidea Core Intelligence), the AI brain that operates "
            "the Grevidea environmental intelligence platform. You are speaking "
            "with a developer on your team.\n\n"
            "RULES:\n"
            "1. If you know the answer, respond directly (DIRECT mode).\n"
            "2. If the question is complex or architectural, ask clarifying "
            "   questions to help the developer think (SOCRATIC mode).\n"
            "3. Never hallucinate data. If unsure, say so.\n"
            "4. Reference past events from memory when relevant.\n"
            "5. Be concise but thorough.\n\n"
        )

        if memory_context:
            system_prompt += f"RELEVANT MEMORIES:\n{memory_context}\n\n"

        # Build tools context
        active_tools = self._tools.get_active_tools()
        if active_tools:
            tools_desc = "\n".join([
                f"- {t.name}: {t.description}" for t in active_tools
            ])
            system_prompt += f"AVAILABLE TOOLS:\n{tools_desc}\n\n"

        try:
            response = await self._llm_invoke(
                system_prompt=system_prompt,
                messages=history,
                user_message=message,
            )

            # Determine mode based on response content
            mode = "socratic" if "?" in response and len(response.split("?")) > 1 else "direct"

            return response, [], mode

        except Exception as e:
            logger.error(f"LLM chat failed: {e}")
            return (
                f"I'm having trouble connecting to my LLM backend: {str(e)}. "
                "Try using 'status', 'tools', or 'memories' for direct commands.",
                [],
                "direct",
            )

    # ── Direct Dispatch (No LLM Fallback) ────────────────────────────

    async def _direct_dispatch(
        self,
        message: str,
        memories: list[MemoryEntry],
    ) -> tuple[str, list[str]]:
        """
        Respond without LLM by dispatching to tools based on keywords.
        Used when no LLM provider is available.
        """
        tools_used = []
        msg_lower = message.lower()

        # Keyword-based tool dispatch
        if any(kw in msg_lower for kw in ["error", "bug", "fail", "crash", "issue"]):
            tool = self._tools.get_tool("log_analyzer")
            if tool and self._tools.is_tool_active("log_analyzer"):
                record = await tool.safe_execute(hours=24)
                self._mythos.log_tool_call(record)
                tools_used.append("log_analyzer")

                # Also recall relevant memories
                memory_text = ""
                if memories:
                    memory_text = "\n\nRelevant past events:\n" + "\n".join([
                        f"  • {m.text[:100]}" for m in memories[:3]
                    ])

                return (
                    f"I ran the log analyzer for the last 24 hours. "
                    f"Here's what I found: {record.output_data}"
                    f"{memory_text}",
                    tools_used,
                )

        if any(kw in msg_lower for kw in ["health", "cpu", "memory", "disk", "load"]):
            tool = self._tools.get_tool("health_check")
            if tool:
                record = await tool.safe_execute()
                self._mythos.log_tool_call(record)
                tools_used.append("health_check")
                return (
                    f"System health check results: {record.output_data}",
                    tools_used,
                )

        # Default: return memories if available
        if memories:
            memory_text = "\n".join([f"  • {m.text[:150]}" for m in memories[:5]])
            return (
                f"I don't have an LLM connected to give a detailed answer, "
                f"but here's what I found in my memory:\n{memory_text}\n\n"
                f"Tip: Connect an LLM (Ollama/Groq/Mistral) for full "
                f"conversational capabilities.",
                tools_used,
            )

        return (
            "I'm operating without an LLM backend. I can respond to direct "
            "commands: 'status', 'tools', 'memories', or ask about 'errors'. "
            "Connect Ollama, Groq, or Mistral for full capabilities.",
            tools_used,
        )

    # ── Session Management ───────────────────────────────────────────

    def get_session_history(self, session_id: str) -> list[dict[str, str]]:
        """Get conversation history for a session."""
        return self._sessions.get(session_id, [])

    def clear_session(self, session_id: str) -> None:
        """Clear a session's history."""
        self._sessions.pop(session_id, None)

    @property
    def active_sessions(self) -> int:
        return len(self._sessions)
