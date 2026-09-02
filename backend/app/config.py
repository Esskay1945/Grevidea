"""
GCI Configuration — Central config for the Grevidea Core Intelligence brain.

Manages LLM fallback chain (Ollama → Groq → Mistral), database paths,
Amygdala thresholds, SEAL loop intervals, and Dreamer schedules.
"""

from __future__ import annotations

import os
from enum import Enum
from pathlib import Path
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings


class LLMProvider(str, Enum):
    """Supported LLM providers in fallback order."""
    OLLAMA = "ollama"
    GROQ = "groq"
    MISTRAL = "mistral"


class Settings(BaseSettings):
    """
    Central configuration for the GCI brain.
    Values are loaded from environment variables or .env file.
    """

    # ── Project ──────────────────────────────────────────────────────
    app_name: str = "Grevidea Core Intelligence"
    app_version: str = "0.1.0"
    debug: bool = False

    # ── Database Paths ───────────────────────────────────────────────
    # SQLite for structured data (events, tool logs, state)
    # Designed for easy swap to PostgreSQL via the mythos abstraction layer
    sqlite_db_path: str = Field(
        default="data/gci_brain.db",
        description="Path to the SQLite database file (relative to backend/)"
    )
    # ChromaDB for vector memory (Open Mythos semantic search)
    chromadb_persist_dir: str = Field(
        default="data/chromadb",
        description="Directory for ChromaDB persistence"
    )
    chromadb_collection_name: str = "mythos"

    # ── LLM Provider Chain (Ollama → Groq → Mistral) ────────────────
    # Tier 1: Ollama (local/offline)
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.1:8b"
    ollama_enabled: bool = True

    # Tier 2: Groq (online, fast cloud inference)
    groq_api_key: Optional[str] = None
    groq_model: str = "llama-3.1-70b-versatile"
    groq_enabled: bool = True

    # Tier 3: Mistral (final fallback)
    mistral_api_key: Optional[str] = None
    mistral_model: str = "mistral-large-latest"
    mistral_enabled: bool = True

    # LLM parameters
    llm_temperature: float = 0.1
    llm_max_tokens: int = 4096
    llm_timeout: int = 60  # seconds

    # ── SEAL Loop ────────────────────────────────────────────────────
    seal_loop_interval_seconds: int = Field(
        default=60,
        description="How often the SEAL loop runs (Sense-Evaluate-Act-Learn)"
    )
    seal_loop_enabled: bool = True

    # ── Amygdala (Survival & Load-Shedding) ──────────────────────────
    amygdala_cpu_threshold: float = Field(
        default=85.0,
        description="CPU usage % that triggers survival mode"
    )
    amygdala_memory_threshold: float = Field(
        default=90.0,
        description="Memory usage % that triggers survival mode"
    )
    amygdala_request_rate_threshold: int = Field(
        default=500,
        description="Requests per minute that triggers survival mode"
    )
    amygdala_cooldown_seconds: int = Field(
        default=300,
        description="Seconds of safe metrics before exiting survival mode"
    )
    amygdala_check_interval_seconds: int = Field(
        default=10,
        description="How often the Amygdala checks system vitals"
    )

    # ── Dreamer (Nightly Consolidation) ──────────────────────────────
    dreamer_schedule_hour: int = Field(
        default=3,
        description="Hour (24h IST) to run the Dreaming Phase"
    )
    dreamer_schedule_minute: int = 0
    dreamer_memory_retention_days: int = Field(
        default=7,
        description="Days before detailed tool call logs are purged"
    )
    dreamer_compression_age_hours: int = Field(
        default=24,
        description="Hours before memories are eligible for compression"
    )

    # ── Shadow Simulator ─────────────────────────────────────────────
    shadow_timeout_seconds: int = Field(
        default=10,
        description="Max seconds a shadow simulation can run before timeout"
    )
    shadow_min_test_cases: int = Field(
        default=3,
        description="Minimum test cases required before promoting a fix"
    )

    # ── API Server ───────────────────────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8000

    # ── Rust Axum Gateway ─────────────────────────────────────────────
    # The Rust gateway runs as a sibling service. The Brain calls it
    # via RustToolProxy when the LLM decides to use a deterministic tool.
    axum_gateway_url: str = Field(
        default="http://localhost:3000",
        description="URL of the Rust Axum gateway (58 feature tools live here)"
    )

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "env_prefix": "GCI_",
        "case_sensitive": False,
    }


def get_settings() -> Settings:
    """Get the singleton settings instance."""
    return Settings()


def get_data_dir() -> Path:
    """Ensure the data directory exists and return its path."""
    data_dir = Path("data")
    data_dir.mkdir(parents=True, exist_ok=True)
    return data_dir
