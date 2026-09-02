"""
GCI Main — FastAPI application entrypoint.

Boots the Grevidea Core Intelligence brain and exposes REST endpoints.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from app.api.brain_router import router as brain_router
from app.brain.core import GCICore
from app.config import get_settings

# ── Logging ──────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-20s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("gci")

# ── Global Brain Instance ────────────────────────────────────────────

gci_brain: GCICore = None  # type: ignore


# ── App Lifecycle ────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage the GCI brain lifecycle (startup → shutdown)."""
    global gci_brain

    logger.info("=" * 60)
    logger.info("  GREVIDEA CORE INTELLIGENCE — Booting up...")
    logger.info("=" * 60)

    # Initialize the brain
    settings = get_settings()
    gci_brain = GCICore(settings)

    # Run boot sequence (LLM init, SEAL start, Amygdala start)
    await gci_brain.startup()

    logger.info("=" * 60)
    logger.info("  GCI is ONLINE. Brain is ready.")
    logger.info(f"  Swagger UI: http://{settings.host}:{settings.port}/docs")
    logger.info("=" * 60)

    yield  # App is running

    # Shutdown
    logger.info("GCI shutting down...")
    await gci_brain.shutdown()
    logger.info("GCI shutdown complete.")


# ── FastAPI App ──────────────────────────────────────────────────────

app = FastAPI(
    title="Grevidea Core Intelligence (GCI)",
    description=(
        "The AI Brain powering the Grevidea environmental intelligence platform. "
        "GCI uses SEAL logic (Sense-Evaluate-Act-Learn), Open Mythos memory, "
        "an Amygdala survival protocol, Shadow Simulator for self-healing, "
        "and a Dreamer for nightly consolidation."
    ),
    version="0.1.0",
    lifespan=lifespan,
)

# ── CORS (allow Flutter frontend and Axum gateway) ──────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request Tracking Middleware (feeds the Amygdala) ─────────────────

@app.middleware("http")
async def track_requests(request, call_next):
    """Track incoming requests for the Amygdala's RPM calculation."""
    if gci_brain and gci_brain.amygdala:
        gci_brain.amygdala.record_request()
    response = await call_next(request)
    return response


# ── Routes ───────────────────────────────────────────────────────────

app.include_router(brain_router)


@app.get("/admin", tags=["Dashboard"], response_class=HTMLResponse)
@app.get("/dashboard", tags=["Dashboard"], response_class=HTMLResponse)
async def dashboard():
    """Admin Command Center & Live Telemetry HUD for developers and creators."""
    static_file = Path(__file__).parent / "static" / "index.html"
    if static_file.exists():
        return HTMLResponse(content=static_file.read_text(encoding="utf-8"))
    return HTMLResponse(
        content="<h1>GCI Admin Dashboard initializing... please refresh in a moment.</h1>"
    )


@app.get("/", tags=["Root"])
async def root():
    """Root endpoint — confirms the brain is alive with quick links."""
    return {
        "name": "Grevidea Core Intelligence (GCI)",
        "version": "0.1.0",
        "status": "online",
        "message": "The brain is alive. Visit /admin for the Live Command Center UI, or /docs for OpenAPI specifications.",
        "links": {
            "admin_ui": "/admin",
            "dashboard": "/dashboard",
            "api_docs": "/docs",
            "status": "/brain/status",
            "telemetry": "/brain/telemetry/summary",
        },
    }


@app.get("/health", tags=["Root"])
async def health():
    """Quick health check for load balancers / Docker."""
    return {"status": "ok"}

