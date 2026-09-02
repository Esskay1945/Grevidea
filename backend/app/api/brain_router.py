"""
GCI Brain Router — FastAPI REST endpoints for interacting with the brain.

These endpoints are designed to be consumed by:
    1. Developers via Swagger UI or terminal tools (now)
    2. The Rust (Axum) API server as an internal microservice (later)
"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from app.brain.models.schemas import (
    BrainStatusResponse,
    ChatRequest,
    ChatResponse,
    MorningBriefResponse,
    MythosSearchRequest,
    MythosSearchResponse,
    BrainEvent,
    EventType,
    MemoryEntry,
)

router = APIRouter(prefix="/brain", tags=["GCI Brain"])


def get_brain():
    """
    Dependency that returns the GCI core instance.
    Injected at app startup in main.py.
    """
    from app.main import gci_brain
    return gci_brain


# ── Chat (Socratic Interface) ───────────────────────────────────────


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, brain=Depends(get_brain)):
    """
    Send a message to the GCI brain's Socratic interface.

    The brain will either:
    - Answer directly using tools and memory (DIRECT mode)
    - Ask clarifying questions for complex problems (SOCRATIC mode)
    """
    try:
        return await brain.chat(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Brain error: {str(e)}")


# ── Status ───────────────────────────────────────────────────────────


@router.get("/status", response_model=BrainStatusResponse)
async def get_status(brain=Depends(get_brain)):
    """
    Get the current status of the GCI brain.

    Returns system health, SEAL loop status, survival mode state,
    tool counts, memory counts, and active LLM provider.
    """
    return brain.get_status()


# ── Open Mythos (Memory) ────────────────────────────────────────────


@router.post("/mythos/search", response_model=MythosSearchResponse)
async def search_mythos(request: MythosSearchRequest, brain=Depends(get_brain)):
    """
    Semantic search over the Open Mythos memory.

    Search past events, conversations, and patterns using
    natural language queries.
    """
    results = brain.mythos.recall(request.query, top_k=request.top_k)
    return MythosSearchResponse(
        results=results,
        query=request.query,
        total_found=len(results),
    )


@router.get("/mythos/events")
async def get_events(
    event_type: Optional[str] = None,
    limit: int = 50,
    brain=Depends(get_brain),
):
    """
    Get recent structured events from the brain's event log.

    Optional filter by event type:
    SENSE, EVALUATE, ACT, LEARN, ERROR, HEAL, SURVIVAL_ENTER,
    SURVIVAL_EXIT, DREAM, SHADOW_PASS, SHADOW_FAIL, TOOL_CALL, SYSTEM
    """
    try:
        et = EventType(event_type) if event_type else None
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid event type: {event_type}. "
                   f"Valid types: {[e.value for e in EventType]}",
        )

    events = brain.mythos.get_recent_events(event_type=et, limit=limit)
    return {"events": [e.model_dump() for e in events], "count": len(events)}


# ── Tools ────────────────────────────────────────────────────────────


@router.get("/tools")
async def list_tools(brain=Depends(get_brain)):
    """List all registered tools with their status and descriptions."""
    return {
        "tools": brain.tools.list_tools(),
        "total": brain.tools.total_count,
        "active": brain.tools.active_count,
        "disabled": brain.tools.disabled_count,
    }


# ── Morning Brief ───────────────────────────────────────────────────


@router.get("/morning-brief", response_model=MorningBriefResponse)
async def get_morning_brief(brain=Depends(get_brain)):
    """
    Get the latest morning brief from the Dreamer.

    The morning brief summarizes overnight events, fixes applied,
    anomalies detected, and tools with high failure rates.
    """
    return brain.dreamer.get_morning_brief()


@router.post("/dream")
async def trigger_dream(brain=Depends(get_brain)):
    """
    Manually trigger a Dreamer REM cycle.

    This runs the full nightly consolidation: memory compression,
    stale data purge, tool health analysis, and morning brief generation.
    """
    try:
        brief = await brain.trigger_dream()
        return {
            "status": "REM cycle complete",
            "brief": brief.model_dump(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dream cycle error: {str(e)}")


# ── Survival Mode (Amygdala) ────────────────────────────────────────


@router.get("/survival")
async def get_survival_status(brain=Depends(get_brain)):
    """
    Get the current Amygdala survival mode status and thresholds.
    """
    return {
        "survival_mode": brain.amygdala.is_survival_active,
        "survival_duration": brain.amygdala.survival_duration,
        "thresholds": {
            "cpu_percent": brain._settings.amygdala_cpu_threshold,
            "memory_percent": brain._settings.amygdala_memory_threshold,
            "requests_per_minute": brain._settings.amygdala_request_rate_threshold,
        },
        "cooldown_seconds": brain._settings.amygdala_cooldown_seconds,
    }


# ── SEAL Loop Control ───────────────────────────────────────────────


@router.post("/seal/pause")
async def pause_seal(brain=Depends(get_brain)):
    """Pause the SEAL loop (it continues running but skips cycles)."""
    brain.seal.pause()
    return {"status": "SEAL loop paused"}


@router.post("/seal/resume")
async def resume_seal(brain=Depends(get_brain)):
    """Resume a paused SEAL loop."""
    brain.seal.resume()
    return {"status": "SEAL loop resumed"}


@router.post("/seal/run-once")
async def seal_run_once(brain=Depends(get_brain)):
    """Manually trigger a single SEAL cycle (for testing)."""
    try:
        result = await brain.seal.run_once()
        return {
            "status": "SEAL cycle complete",
            "result": result.model_dump(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"SEAL cycle error: {str(e)}")


# ── Survival Controls (Emergency Drill) ──────────────────────────────


@router.post("/survival/trigger")
async def trigger_survival(reason: Optional[str] = "Manual developer emergency drill", brain=Depends(get_brain)):
    """Manually trigger Amygdala survival mode for testing."""
    await brain.amygdala.enter_survival_mode(reason=reason or "Manual drill")
    return {
        "status": "Survival mode triggered",
        "survival_mode": brain.amygdala.is_survival_active,
        "disabled_tools": brain.tools.disabled_count,
    }


@router.post("/survival/exit")
async def exit_survival(brain=Depends(get_brain)):
    """Manually exit Amygdala survival mode."""
    await brain.amygdala.exit_survival_mode()
    return {
        "status": "Survival mode deactivated",
        "survival_mode": brain.amygdala.is_survival_active,
        "active_tools": brain.tools.active_count,
    }


# ── Shadow Simulator Runner ─────────────────────────────────────────


@router.post("/shadow/simulate")
async def run_shadow_simulation(
    payload: dict,
    brain=Depends(get_brain),
):
    """
    Execute a fix in the Shadow Simulator sandbox.
    Expected JSON payload: { "fix_code": "def fix(x): ...", "test_cases": [...], "fix_description": "..." }
    """
    fix_code = payload.get("fix_code", "def fix(input_data):\n    return input_data")
    test_cases = payload.get("test_cases", [
        {"input": {"val": 1}, "expected_output": {"val": 1}},
        {"input": {"val": 2}, "expected_output": {"val": 2}},
        {"input": {"val": 3}, "expected_output": {"val": 3}},
    ])
    description = payload.get("fix_description", "Test self-evolution fix")

    result = await brain.shadow.simulate(
        fix_code=fix_code,
        test_cases=test_cases,
        fix_description=description,
    )
    return {
        "status": "Simulation complete",
        "result": result.model_dump(),
    }


@router.get("/shadow/history")
async def get_shadow_history(brain=Depends(get_brain)):
    """Get history of all shadow simulation runs."""
    return {
        "history": [r.model_dump() for r in brain.shadow.results_history],
        "count": len(brain.shadow.results_history),
    }


# ── Live Telemetry & Traffic Simulator ──────────────────────────────


@router.get("/telemetry/summary")
async def get_telemetry_summary(brain=Depends(get_brain)):
    """
    Unified telemetry snapshot for the Admin Command Center.
    Returns status, vitals, last SEAL cycle, memory stats, and recent events.
    """
    state = brain.amygdala.check_vitals()
    state.seal_loop_running = brain.seal.is_running
    recent_events = brain.mythos.get_recent_events(limit=15)
    recent_tools = brain.mythos.get_tool_history(limit=10)

    last_seal = brain.seal.last_cycle
    morning_brief = brain.dreamer.last_brief

    return {
        "status": {
            "app_name": brain._settings.app_name,
            "version": brain._settings.app_version,
            "llm_provider": brain._llm_provider or "none",
            "uptime_seconds": round(brain.uptime, 1),
            "survival_mode": brain.amygdala.is_survival_active,
            "survival_duration": brain.amygdala.survival_duration,
            "seal_running": brain.seal.is_running,
            "seal_cycle_count": brain.seal.cycle_count,
        },
        "vitals": state.model_dump(),
        "memory": {
            "total_events": brain.mythos.get_event_count(),
            "total_memories": brain.mythos.get_memory_count(),
            "error_count_24h": brain.mythos.get_error_count(since_hours=24),
        },
        "tools": {
            "total": brain.tools.total_count,
            "active": brain.tools.active_count,
            "disabled": brain.tools.disabled_count,
            "list": brain.tools.list_tools(),
            "recent_calls": [t.model_dump() for t in recent_tools],
        },
        "seal_last_cycle": last_seal.model_dump() if last_seal else None,
        "recent_events": [e.model_dump() for e in recent_events],
        "morning_brief": morning_brief.model_dump() if morning_brief else None,
    }


@router.post("/telemetry/simulate-traffic")
async def simulate_mock_traffic(
    payload: Optional[dict] = None,
    brain=Depends(get_brain),
):
    """
    Simulate user actions (e.g. carbon calculations, AQI queries, disaster alerts)
    to test the live brain telemetry and load tracking.
    """
    import random
    data = payload or {}
    event_count = data.get("count", 5)
    action_types = [
        ("CARBON_CALC", "User logged transport commute (EV + Metro)", "INFO"),
        ("AQI_QUERY", "User requested AQI spatial heatmap for Koramangala, BLR", "INFO"),
        ("NUDGE_TRIGGER", "Autonomous nudge delivered: 'Solar peak hours detected - charge devices'", "INFO"),
        ("DISASTER_WATCH", "Monitored micro-weather anomaly sensor cluster #42", "INFO"),
        ("TREE_PLANT", "Gamification milestone: User planted virtual mangrove #104", "INFO"),
    ]

    generated = []
    for _ in range(min(event_count, 50)):
        act_type, msg, sev = random.choice(action_types)
        brain.amygdala.record_request()
        ev_id = brain.mythos.log_event(BrainEvent(
            event_type=EventType.ACT,
            severity=Severity(sev),
            source="user_traffic",
            message=f"Live User Traffic: {msg}",
            data={"action": act_type, "simulated": True},
        ))
        generated.append(ev_id)

    return {
        "status": f"Simulated {len(generated)} user interactions",
        "event_ids": generated,
        "current_rpm": brain.amygdala._calculate_rpm(),
    }

