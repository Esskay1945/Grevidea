"""
GCI Data Models — Pydantic schemas for the brain's internal data structures.

These models define the shape of every event, memory entry, tool call,
and system state that flows through the GCI brain.
"""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


# ── Enums ────────────────────────────────────────────────────────────


class EventType(str, Enum):
    """Types of events the brain can log."""
    SENSE = "SENSE"
    EVALUATE = "EVALUATE"
    ACT = "ACT"
    LEARN = "LEARN"
    ERROR = "ERROR"
    HEAL = "HEAL"
    SURVIVAL_ENTER = "SURVIVAL_ENTER"
    SURVIVAL_EXIT = "SURVIVAL_EXIT"
    DREAM = "DREAM"
    SHADOW_PASS = "SHADOW_PASS"
    SHADOW_FAIL = "SHADOW_FAIL"
    TOOL_CALL = "TOOL_CALL"
    SYSTEM = "SYSTEM"


class Severity(str, Enum):
    """Severity levels for evaluated anomalies."""
    CRITICAL = "CRITICAL"
    WARNING = "WARNING"
    INFO = "INFO"


class ToolStatus(str, Enum):
    """Outcome of a tool execution."""
    SUCCESS = "SUCCESS"
    FAILURE = "FAILURE"
    TIMEOUT = "TIMEOUT"
    SKIPPED = "SKIPPED"  # Skipped due to survival mode


# ── Core Data Models ─────────────────────────────────────────────────


class BrainEvent(BaseModel):
    """A timestamped event logged by the brain."""
    id: Optional[int] = None
    event_type: EventType
    severity: Severity = Severity.INFO
    source: str = Field(
        description="Which component generated this event (seal, amygdala, dreamer, etc.)"
    )
    message: str
    data: Optional[dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    model_config = {"from_attributes": True}


class MemoryEntry(BaseModel):
    """A chunk stored in the Open Mythos semantic memory (ChromaDB)."""
    id: Optional[str] = None
    text: str = Field(description="The natural-language content of this memory")
    source: str = Field(description="Which component created this memory")
    memory_type: str = Field(
        default="general",
        description="Category: general, daily_digest, tool_pattern, anomaly, fix"
    )
    metadata: dict[str, Any] = Field(default_factory=dict)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ToolCallRecord(BaseModel):
    """Full audit trail of a tool invocation."""
    id: Optional[int] = None
    tool_name: str
    input_data: dict[str, Any] = Field(default_factory=dict)
    output_data: Optional[dict[str, Any]] = None
    status: ToolStatus = ToolStatus.SUCCESS
    duration_ms: Optional[float] = None
    error_message: Optional[str] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    model_config = {"from_attributes": True}


class SystemState(BaseModel):
    """Current health snapshot of the system."""
    cpu_percent: float = 0.0
    memory_percent: float = 0.0
    disk_percent: float = 0.0
    active_requests: int = 0
    requests_per_minute: float = 0.0
    survival_mode: bool = False
    seal_loop_running: bool = False
    uptime_seconds: float = 0.0
    active_tools: int = 0
    disabled_tools: int = 0
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ShadowResult(BaseModel):
    """Outcome of a shadow simulation run."""
    fix_id: str
    fix_description: str
    test_cases_run: int = 0
    test_cases_passed: int = 0
    test_cases_failed: int = 0
    passed: bool = False
    error_message: Optional[str] = None
    latency_ms: Optional[float] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Anomaly(BaseModel):
    """An anomaly detected during the SEAL Evaluate phase."""
    description: str
    severity: Severity
    source: str = Field(description="Which system/component the anomaly was found in")
    suggested_action: Optional[str] = None
    tool_to_use: Optional[str] = None


class SEALCycleResult(BaseModel):
    """Result of a complete SEAL loop cycle."""
    cycle_id: str
    sensed_data: dict[str, Any] = Field(default_factory=dict)
    anomalies: list[Anomaly] = Field(default_factory=list)
    actions_taken: list[str] = Field(default_factory=list)
    lessons_learned: list[str] = Field(default_factory=list)
    duration_ms: float = 0.0
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# ── API Request/Response Models ──────────────────────────────────────


class ChatRequest(BaseModel):
    """Request body for the /brain/chat endpoint."""
    message: str
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    """Response from the /brain/chat endpoint."""
    response: str
    session_id: str
    tools_used: list[str] = Field(default_factory=list)
    memories_recalled: int = 0
    mode: str = Field(default="direct", description="direct or socratic")


class MythosSearchRequest(BaseModel):
    """Request body for /brain/mythos/search."""
    query: str
    top_k: int = 5


class MythosSearchResponse(BaseModel):
    """Response from /brain/mythos/search."""
    results: list[MemoryEntry] = Field(default_factory=list)
    query: str
    total_found: int = 0


class BrainStatusResponse(BaseModel):
    """Response from /brain/status."""
    app_name: str
    version: str
    system_state: SystemState
    seal_loop_active: bool
    survival_mode: bool
    total_tools: int
    total_memories: int
    llm_provider: str
    uptime_seconds: float


class MorningBriefResponse(BaseModel):
    """Response from /brain/morning-brief."""
    summary: str
    fixes_applied: int = 0
    anomalies_detected: int = 0
    tools_failing: list[str] = Field(default_factory=list)
    generated_at: Optional[datetime] = None
