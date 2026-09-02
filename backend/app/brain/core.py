"""
GCI Core — The Orchestrator. The CEO. The Single Brain.

This is the entry point that initializes and coordinates ALL brain
components: SEAL loop, Mythos, Shadow Simulator, Amygdala, Dreamer,
Socratic interface, and the Tool Registry.

It also manages the 3-tier LLM fallback chain:
    Ollama (local/offline) → Groq (cloud) → Mistral (fallback)
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Optional

from app.brain.amygdala import Amygdala
from app.brain.dreamer import Dreamer
from app.brain.models.schemas import (
    BrainEvent,
    BrainStatusResponse,
    ChatRequest,
    ChatResponse,
    EventType,
    Severity,
    SystemState,
)
from app.brain.mythos import OpenMythos
from app.brain.seal import SEALLoop
from app.brain.shadow import ShadowSimulator
from app.brain.socratic import SocraticInterface
from app.brain.tools.registry import ToolRegistry
from app.config import Settings, get_settings

logger = logging.getLogger("gci.core")


class GCICore:
    """
    Grevidea Core Intelligence — The Single Brain.

    Initializes all subsystems, manages the LLM provider fallback chain,
    and exposes a clean API for the FastAPI router.
    """

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._start_time = time.time()
        self._llm_provider: Optional[str] = None
        self._llm_client: Any = None

        # ── Initialize subsystems ────────────────────────────────
        logger.info("🧠 Initializing Grevidea Core Intelligence...")

        # 1. Open Mythos (Memory)
        self.mythos = OpenMythos(self._settings)

        # 2. Tool Registry
        self.tools = ToolRegistry()
        discovered = self.tools.auto_discover()
        logger.info(f"Discovered {discovered} built-in tools.")

        # Register all 58 Rust Axum tools as proxies
        # The LLM Orchestrator calls these by name; they forward to the Rust gateway
        self._register_rust_tools()


        # 3. Shadow Simulator
        self.shadow = ShadowSimulator(self._settings, self.mythos)

        # 4. Amygdala
        self.amygdala = Amygdala(self._settings, self.mythos, self.tools)

        # 5. SEAL Loop
        self.seal = SEALLoop(
            settings=self._settings,
            mythos=self.mythos,
            tool_registry=self.tools,
            llm_invoke=self._llm_evaluate,
            amygdala_trigger=self.amygdala.enter_survival_mode,
        )

        # 6. Dreamer
        self.dreamer = Dreamer(
            settings=self._settings,
            mythos=self.mythos,
            llm_invoke=self._llm_invoke,
        )

        # 7. Socratic Interface
        self.socratic = SocraticInterface(
            settings=self._settings,
            mythos=self.mythos,
            tool_registry=self.tools,
            llm_invoke=self._llm_chat,
        )

        # Log startup
        self.mythos.log_event(BrainEvent(
            event_type=EventType.SYSTEM,
            source="core",
            message="GCI brain initialized successfully.",
            data={
                "tools_registered": self.tools.total_count,
                "settings": {
                    "seal_interval": self._settings.seal_loop_interval_seconds,
                    "amygdala_cpu_threshold": self._settings.amygdala_cpu_threshold,
                    "dreamer_hour": self._settings.dreamer_schedule_hour,
                },
            },
        ))

        logger.info("🧠 GCI brain initialized successfully.")

    # ── Rust Tool Registration ────────────────────────────────────────

    def _register_rust_tools(self) -> None:
        """
        Register all 58 Rust Axum tools as Brain-callable proxies.

        These tools live in the Rust gateway but are accessible to the LLM
        Orchestrator exactly like any other Python tool. The proxy pattern
        keeps deterministic execution in Rust while the Brain decides WHAT to call.
        """
        try:
            from app.brain.tools.builtin.rust_proxy import ALL_RUST_PROXIES
            for proxy in ALL_RUST_PROXIES:
                self.tools.register(proxy)
            logger.info(
                f"✅ Registered {len(ALL_RUST_PROXIES)} Rust gateway tools as Brain proxies. "
                f"Total tools: {self.tools.total_count}"
            )
        except Exception as e:
            # Non-fatal: Brain works without gateway during development
            logger.warning(
                f"⚠️  Rust tool proxies not loaded (gateway may not be running): {e}. "
                f"Brain will operate in standalone mode."
            )

    # ── LLM Provider Management ──────────────────────────────────────


    async def _init_llm(self) -> None:
        """
        Initialize the LLM provider using the 3-tier fallback chain:
            1. Ollama (local) → 2. Groq (cloud) → 3. Mistral (cloud)
        """
        # Tier 1: Ollama (local/offline)
        if self._settings.ollama_enabled:
            try:
                import httpx
                async with httpx.AsyncClient(timeout=5) as client:
                    resp = await client.get(f"{self._settings.ollama_base_url}/api/tags")
                    if resp.status_code == 200:
                        self._llm_provider = "ollama"
                        logger.info(
                            f"✅ LLM Provider: Ollama ({self._settings.ollama_model})"
                        )
                        return
            except Exception as e:
                logger.warning(f"Ollama not available: {e}")

        # Tier 2: Groq (cloud)
        if self._settings.groq_enabled and self._settings.groq_api_key:
            try:
                from langchain_groq import ChatGroq
                self._llm_client = ChatGroq(
                    api_key=self._settings.groq_api_key,
                    model=self._settings.groq_model,
                    temperature=self._settings.llm_temperature,
                    max_tokens=self._settings.llm_max_tokens,
                )
                self._llm_provider = "groq"
                logger.info(
                    f"✅ LLM Provider: Groq ({self._settings.groq_model})"
                )
                return
            except Exception as e:
                logger.warning(f"Groq not available: {e}")

        # Tier 3: Mistral (fallback)
        if self._settings.mistral_enabled and self._settings.mistral_api_key:
            try:
                from langchain_mistralai import ChatMistralAI
                self._llm_client = ChatMistralAI(
                    api_key=self._settings.mistral_api_key,
                    model=self._settings.mistral_model,
                    temperature=self._settings.llm_temperature,
                    max_tokens=self._settings.llm_max_tokens,
                )
                self._llm_provider = "mistral"
                logger.info(
                    f"✅ LLM Provider: Mistral ({self._settings.mistral_model})"
                )
                return
            except Exception as e:
                logger.warning(f"Mistral not available: {e}")

        # No LLM available
        self._llm_provider = "none"
        logger.warning(
            "⚠️ No LLM provider available. Brain will operate in "
            "rule-based mode without AI reasoning capabilities."
        )

    async def _llm_invoke(self, prompt: str) -> str:
        """
        Send a prompt to the active LLM provider.
        Used by the SEAL loop and Dreamer for evaluation tasks.
        """
        if self._llm_provider == "ollama":
            return await self._ollama_invoke(prompt)
        elif self._llm_client:
            from langchain_core.messages import HumanMessage
            response = await self._llm_client.ainvoke([HumanMessage(content=prompt)])
            return response.content
        else:
            raise RuntimeError("No LLM provider available.")

    async def _llm_evaluate(self, prompt: str) -> str:
        """Wrapper for SEAL loop's LLM evaluation calls."""
        return await self._llm_invoke(prompt)

    async def _llm_chat(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        user_message: str,
    ) -> str:
        """
        Full chat-style LLM invocation with system prompt and history.
        Used by the Socratic interface.
        """
        if self._llm_provider == "ollama":
            # Build a single prompt from history for Ollama
            history_text = "\n".join([
                f"{m['role'].upper()}: {m['content']}"
                for m in messages[-6:]
            ])
            full_prompt = f"{system_prompt}\n\n{history_text}\nUSER: {user_message}\nASSISTANT:"
            return await self._ollama_invoke(full_prompt)

        elif self._llm_client:
            from langchain_core.messages import AIMessage, HumanMessage, SystemMessage

            lc_messages = [SystemMessage(content=system_prompt)]
            for m in messages[-6:]:
                if m["role"] == "user":
                    lc_messages.append(HumanMessage(content=m["content"]))
                elif m["role"] == "assistant":
                    lc_messages.append(AIMessage(content=m["content"]))
            lc_messages.append(HumanMessage(content=user_message))

            response = await self._llm_client.ainvoke(lc_messages)
            return response.content

        else:
            return (
                f"GCI Brain Intelligence: Analyzed '{user_message}'. Operating in deterministic autonomous mode "
                f"with {self.tools.total_count} registered tools across all 6 Grevidea Epics."
            )

    async def _ollama_invoke(self, prompt: str) -> str:
        """Call the local Ollama API directly."""
        import httpx

        async with httpx.AsyncClient(
            timeout=self._settings.llm_timeout
        ) as client:
            resp = await client.post(
                f"{self._settings.ollama_base_url}/api/generate",
                json={
                    "model": self._settings.ollama_model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": self._settings.llm_temperature,
                        "num_predict": self._settings.llm_max_tokens,
                    },
                },
            )
            resp.raise_for_status()
            return resp.json().get("response", "")

    # ── Startup & Shutdown ───────────────────────────────────────────

    async def startup(self) -> None:
        """
        Boot sequence: Initialize LLM, start SEAL loop, start Amygdala.
        Called by FastAPI's on_startup event.
        """
        logger.info("🚀 GCI boot sequence starting...")

        # Initialize LLM provider
        await self._init_llm()

        # Start the Amygdala monitor
        await self.amygdala.start()

        # Start the SEAL loop
        if self._settings.seal_loop_enabled:
            await self.seal.start()

        self.mythos.log_event(BrainEvent(
            event_type=EventType.SYSTEM,
            source="core",
            message=(
                f"GCI boot complete. LLM: {self._llm_provider}. "
                f"SEAL: {'running' if self.seal.is_running else 'off'}. "
                f"Amygdala: active."
            ),
        ))

        logger.info(
            f"🚀 GCI boot complete. LLM: {self._llm_provider}. "
            f"Tools: {self.tools.total_count}. SEAL: running."
        )

    async def shutdown(self) -> None:
        """
        Graceful shutdown: Stop all background tasks, close connections.
        Called by FastAPI's on_shutdown event.
        """
        logger.info("Shutting down GCI brain...")

        await self.seal.stop()
        await self.amygdala.stop()
        self.mythos.close()

        logger.info("GCI brain shut down cleanly.")

    # ── Public API (Used by brain_router.py) ─────────────────────────

    async def chat(self, request: ChatRequest) -> ChatResponse:
        """Process a developer chat message."""
        return await self.socratic.chat(
            message=request.message,
            session_id=request.session_id,
        )

    def get_status(self) -> BrainStatusResponse:
        """Get complete brain status."""
        state = self.amygdala.check_vitals()
        state.seal_loop_running = self.seal.is_running

        return BrainStatusResponse(
            app_name=self._settings.app_name,
            version=self._settings.app_version,
            system_state=state,
            seal_loop_active=self.seal.is_running,
            survival_mode=self.amygdala.is_survival_active,
            total_tools=self.tools.total_count,
            total_memories=self.mythos.get_memory_count(),
            llm_provider=self._llm_provider or "none",
            uptime_seconds=round(time.time() - self._start_time, 1),
        )

    async def trigger_dream(self):
        """Manually trigger a Dreamer REM cycle."""
        return await self.dreamer.run_rem_cycle()

    @property
    def uptime(self) -> float:
        return time.time() - self._start_time
