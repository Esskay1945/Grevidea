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

        pdf_dir = self._settings.research_pdf_dir
        if not pdf_dir:
            candidate = Path(__file__).resolve().parents[3] / "grevidea" / "Research Papers"
            if candidate.is_dir():
                pdf_dir = str(candidate)
        if pdf_dir:
            from app.brain.research_corpus import ingest_papers
            try:
                ingest_papers(self.mythos, pdf_dir)
            except Exception as e:
                logger.warning(f"Could not ingest research papers from {pdf_dir}: {e}")

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
        from app.brain.llm import LLMChain
        self._llm_client = LLMChain(self._settings)
        self._llm_provider = "none"

    async def _llm_invoke(self, prompt: str) -> str:
        if self._llm_client is None:
            await self._init_llm()
        result = await self._llm_client.chat([{"role": "user", "content": prompt}])
        self._llm_provider = self._llm_client.active
        return result

    async def _llm_evaluate(self, prompt: str) -> str:
        return await self._llm_invoke(prompt)

    async def _llm_chat(self, system_prompt: str, messages: list[dict[str, str]], user_message: str) -> str:
        if self._llm_client is None:
            await self._init_llm()
        history = [{"role": m["role"], "content": m["content"]} for m in messages[-6:]]
        if history and history[-1] == {"role": "user", "content": user_message}:
            history.pop()
        result = await self._llm_client.chat([
            {"role": "system", "content": system_prompt}, *history,
            {"role": "user", "content": user_message},
        ])
        self._llm_provider = self._llm_client.active
        return result

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
            session_id=(f"{request.user_id}:{request.session_id or 'default'}" if request.user_id else request.session_id),
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
