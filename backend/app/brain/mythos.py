"""
Open Mythos — The brain's two-layer memory system.

Layer 1 (Structured): SQLite for events, tool calls, and system state.
    → Append-only audit trail. Fast indexed queries.
    → Designed behind an abstraction so PostgreSQL swap is a config change.

Layer 2 (Semantic): Lightweight in-memory vector store.
    → Natural-language recall: "Have we seen this API fail before?"
    → Uses TF-IDF + cosine similarity (zero C++ dependencies).
    → Production swap to Qdrant/ChromaDB is a config change.
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import re
import sqlite3
import uuid
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

from app.brain.models.schemas import (
    BrainEvent,
    EventType,
    MemoryEntry,
    Severity,
    ToolCallRecord,
    ToolStatus,
)
from app.config import Settings

logger = logging.getLogger("gci.mythos")


# ── Lightweight Vector Store ─────────────────────────────────────────


class _SimpleVectorStore:
    """
    Minimal in-memory vector store using TF-IDF + cosine similarity.

    No external dependencies (no numpy, no scikit-learn, no ChromaDB).
    Pure Python implementation for maximum portability.

    Production: Swap this class for a QdrantStore or ChromaStore adapter.
    """

    def __init__(self) -> None:
        self._documents: dict[str, str] = {}  # id -> text
        self._metadata: dict[str, dict[str, Any]] = {}  # id -> metadata
        self._idf_cache: dict[str, float] = {}
        self._doc_vectors: dict[str, dict[str, float]] = {}  # id -> tf-idf vector

    def add(self, doc_id: str, text: str, metadata: dict[str, Any]) -> None:
        """Add a document to the store."""
        self._documents[doc_id] = text
        self._metadata[doc_id] = metadata
        self._doc_vectors[doc_id] = self._compute_tf(text)
        # Invalidate IDF cache when new docs are added
        self._idf_cache.clear()

    def query(self, query_text: str, top_k: int = 5, where: Optional[dict] = None) -> list[tuple[str, str, dict]]:
        """
        Semantic search: returns top_k most similar documents.
        Returns list of (id, text, metadata) tuples.
        """
        if not self._documents:
            return []

        # Recompute IDF if cache is empty
        if not self._idf_cache:
            self._recompute_idf()

        query_tf = self._compute_tf(query_text)
        query_vec = {
            term: tf * self._idf_cache.get(term, 0)
            for term, tf in query_tf.items()
        }

        scores: list[tuple[str, float]] = []
        for doc_id, doc_tf in self._doc_vectors.items():
            # Apply metadata filter if provided
            if where and not self._matches_filter(doc_id, where):
                continue

            doc_vec = {
                term: tf * self._idf_cache.get(term, 0)
                for term, tf in doc_tf.items()
            }
            score = self._cosine_similarity(query_vec, doc_vec)
            scores.append((doc_id, score))

        scores.sort(key=lambda x: x[1], reverse=True)

        results = []
        for doc_id, _ in scores[:top_k]:
            results.append((
                doc_id,
                self._documents[doc_id],
                self._metadata.get(doc_id, {}),
            ))

        return results

    def delete(self, doc_ids: list[str]) -> int:
        """Delete documents by ID. Returns count deleted."""
        count = 0
        for doc_id in doc_ids:
            if doc_id in self._documents:
                del self._documents[doc_id]
                self._metadata.pop(doc_id, None)
                self._doc_vectors.pop(doc_id, None)
                count += 1
        if count > 0:
            self._idf_cache.clear()
        return count

    def get_all(self, where: Optional[dict] = None) -> list[tuple[str, dict]]:
        """Get all document IDs and metadata, optionally filtered."""
        results = []
        for doc_id, meta in self._metadata.items():
            if where and not self._matches_filter(doc_id, where):
                continue
            results.append((doc_id, meta))
        return results

    def count(self) -> int:
        return len(self._documents)

    # ── Internal Methods ─────────────────────────────────────────

    def _tokenize(self, text: str) -> list[str]:
        """Simple whitespace + punctuation tokenizer."""
        text = text.lower()
        tokens = re.findall(r'\b[a-z0-9]+\b', text)
        return tokens

    def _compute_tf(self, text: str) -> dict[str, float]:
        """Compute term frequency for a document."""
        tokens = self._tokenize(text)
        if not tokens:
            return {}
        counts = Counter(tokens)
        total = len(tokens)
        return {term: count / total for term, count in counts.items()}

    def _recompute_idf(self) -> None:
        """Recompute inverse document frequency across all documents."""
        n_docs = len(self._documents)
        if n_docs == 0:
            return

        doc_freq: dict[str, int] = Counter()
        for doc_tf in self._doc_vectors.values():
            for term in doc_tf:
                doc_freq[term] += 1

        self._idf_cache = {
            term: math.log((n_docs + 1) / (df + 1)) + 1
            for term, df in doc_freq.items()
        }

    def _cosine_similarity(self, vec_a: dict[str, float], vec_b: dict[str, float]) -> float:
        """Compute cosine similarity between two sparse vectors."""
        common_terms = set(vec_a.keys()) & set(vec_b.keys())
        if not common_terms:
            return 0.0

        dot = sum(vec_a[t] * vec_b[t] for t in common_terms)
        mag_a = math.sqrt(sum(v * v for v in vec_a.values()))
        mag_b = math.sqrt(sum(v * v for v in vec_b.values()))

        if mag_a == 0 or mag_b == 0:
            return 0.0

        return dot / (mag_a * mag_b)

    def _matches_filter(self, doc_id: str, where: dict) -> bool:
        """Check if a document's metadata matches the filter."""
        meta = self._metadata.get(doc_id, {})
        for key, value in where.items():
            if isinstance(value, dict) and "$lt" in value:
                if meta.get(key, "") >= value["$lt"]:
                    return False
            elif meta.get(key) != value:
                return False
        return True


# ── Open Mythos ──────────────────────────────────────────────────────


class OpenMythos:
    """
    The brain's complete memory system.

    All database access is funneled through this class so that migrating
    from SQLite to PostgreSQL (or the vector store to Qdrant) is a
    config change, not a rewrite.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._db_path = Path(settings.sqlite_db_path)
        self._db_path.parent.mkdir(parents=True, exist_ok=True)

        # Initialize SQLite (structured memory)
        self._conn = sqlite3.connect(
            str(self._db_path),
            check_same_thread=False,
        )
        self._conn.row_factory = sqlite3.Row
        self._init_tables()

        # Initialize vector store (semantic memory)
        self._vector_store = _SimpleVectorStore()

        logger.info(
            f"Open Mythos initialized. SQLite: {self._db_path}, "
            f"Vector store: in-memory (swap to Qdrant for production)"
        )

    # ── Schema Initialization ────────────────────────────────────────

    def _init_tables(self) -> None:
        """Create SQLite tables if they don't exist."""
        cursor = self._conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                severity TEXT NOT NULL DEFAULT 'INFO',
                source TEXT NOT NULL,
                message TEXT NOT NULL,
                data TEXT,
                timestamp TEXT NOT NULL
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tool_calls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tool_name TEXT NOT NULL,
                input_data TEXT,
                output_data TEXT,
                status TEXT NOT NULL,
                duration_ms REAL,
                error_message TEXT,
                timestamp TEXT NOT NULL
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS system_state (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cpu_percent REAL,
                memory_percent REAL,
                disk_percent REAL,
                active_requests INTEGER DEFAULT 0,
                requests_per_minute REAL DEFAULT 0,
                survival_mode INTEGER DEFAULT 0,
                seal_loop_running INTEGER DEFAULT 0,
                uptime_seconds REAL DEFAULT 0,
                active_tools INTEGER DEFAULT 0,
                disabled_tools INTEGER DEFAULT 0,
                timestamp TEXT NOT NULL
            )
        """)

        # Indexes for fast queries
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_tool_calls_name ON tool_calls(tool_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_tool_calls_timestamp ON tool_calls(timestamp)")

        self._conn.commit()
        logger.info("SQLite tables initialized.")

    # ── Structured Memory (SQLite) ───────────────────────────────────

    def log_event(self, event: BrainEvent) -> int:
        """Append a structured event to the event log. Returns the event ID."""
        cursor = self._conn.cursor()
        cursor.execute(
            """INSERT INTO events (event_type, severity, source, message, data, timestamp)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                event.event_type.value,
                event.severity.value,
                event.source,
                event.message,
                json.dumps(event.data) if event.data else None,
                event.timestamp.isoformat(),
            ),
        )
        self._conn.commit()
        event_id = cursor.lastrowid
        logger.debug(f"Logged event [{event.event_type.value}]: {event.message}")
        return event_id

    def get_recent_events(
        self,
        event_type: Optional[EventType] = None,
        limit: int = 50,
    ) -> list[BrainEvent]:
        """Retrieve recent events, optionally filtered by type."""
        cursor = self._conn.cursor()
        if event_type:
            cursor.execute(
                "SELECT * FROM events WHERE event_type = ? ORDER BY timestamp DESC LIMIT ?",
                (event_type.value, limit),
            )
        else:
            cursor.execute(
                "SELECT * FROM events ORDER BY timestamp DESC LIMIT ?",
                (limit,),
            )

        return [
            BrainEvent(
                id=row["id"],
                event_type=EventType(row["event_type"]),
                severity=Severity(row["severity"]),
                source=row["source"],
                message=row["message"],
                data=json.loads(row["data"]) if row["data"] else None,
                timestamp=datetime.fromisoformat(row["timestamp"]),
            )
            for row in cursor.fetchall()
        ]

    def log_tool_call(self, record: ToolCallRecord) -> int:
        """Log a tool invocation. Returns the record ID."""
        cursor = self._conn.cursor()
        cursor.execute(
            """INSERT INTO tool_calls
                (tool_name, input_data, output_data, status, duration_ms, error_message, timestamp)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                record.tool_name,
                json.dumps(record.input_data),
                json.dumps(record.output_data) if record.output_data else None,
                record.status.value,
                record.duration_ms,
                record.error_message,
                record.timestamp.isoformat(),
            ),
        )
        self._conn.commit()
        return cursor.lastrowid

    def get_tool_history(
        self,
        tool_name: Optional[str] = None,
        limit: int = 20,
    ) -> list[ToolCallRecord]:
        """Get recent tool call records, optionally filtered by tool name."""
        cursor = self._conn.cursor()
        if tool_name:
            cursor.execute(
                "SELECT * FROM tool_calls WHERE tool_name = ? ORDER BY timestamp DESC LIMIT ?",
                (tool_name, limit),
            )
        else:
            cursor.execute(
                "SELECT * FROM tool_calls ORDER BY timestamp DESC LIMIT ?",
                (limit,),
            )

        return [
            ToolCallRecord(
                id=row["id"],
                tool_name=row["tool_name"],
                input_data=json.loads(row["input_data"]) if row["input_data"] else {},
                output_data=json.loads(row["output_data"]) if row["output_data"] else None,
                status=ToolStatus(row["status"]),
                duration_ms=row["duration_ms"],
                error_message=row["error_message"],
                timestamp=datetime.fromisoformat(row["timestamp"]),
            )
            for row in cursor.fetchall()
        ]

    def get_error_count(self, since_hours: int = 24) -> int:
        """Count error events in the last N hours."""
        cutoff = (datetime.now(timezone.utc) - timedelta(hours=since_hours)).isoformat()
        cursor = self._conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) FROM events WHERE event_type = 'ERROR' AND timestamp > ?",
            (cutoff,),
        )
        return cursor.fetchone()[0]

    def get_event_count(self) -> int:
        """Total number of events logged."""
        cursor = self._conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM events")
        return cursor.fetchone()[0]

    # ── Semantic Memory (Vector Store) ───────────────────────────────

    def remember(
        self,
        text: str,
        source: str = "system",
        memory_type: str = "general",
        metadata: Optional[dict[str, Any]] = None,
    ) -> str:
        """Store a new memory entry. Returns the generated memory ID."""
        memory_id = f"mem_{uuid.uuid4().hex[:12]}"
        meta = {
            "source": source,
            "memory_type": memory_type,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            **(metadata or {}),
        }

        self._vector_store.add(memory_id, text, meta)
        logger.debug(f"Remembered [{memory_type}] from {source}: {text[:80]}...")
        return memory_id

    def recall(
        self,
        query: str,
        top_k: int = 5,
        memory_type: Optional[str] = None,
    ) -> list[MemoryEntry]:
        """Semantic search over past memories."""
        where_filter = None
        if memory_type:
            where_filter = {"memory_type": memory_type}

        results = self._vector_store.query(query, top_k=top_k, where=where_filter)

        return [
            MemoryEntry(
                id=doc_id,
                text=text,
                source=meta.get("source", "unknown"),
                memory_type=meta.get("memory_type", "general"),
                metadata=meta,
                timestamp=datetime.fromisoformat(
                    meta.get("timestamp", datetime.now(timezone.utc).isoformat())
                ),
            )
            for doc_id, text, meta in results
        ]

    def get_memory_count(self) -> int:
        """Total number of semantic memory entries."""
        return self._vector_store.count()

    def delete_memories_before(self, before: datetime) -> int:
        """Delete semantic memories older than a given timestamp."""
        cutoff = before.isoformat()
        old_entries = self._vector_store.get_all(where={"timestamp": {"$lt": cutoff}})
        if old_entries:
            ids = [entry_id for entry_id, _ in old_entries]
            deleted = self._vector_store.delete(ids)
            if deleted > 0:
                logger.info(f"Deleted {deleted} memories older than {cutoff}")
            return deleted
        return 0

    def purge_old_tool_logs(self, retention_days: int = 7) -> int:
        """Delete tool call logs older than retention_days."""
        cutoff = (datetime.now(timezone.utc) - timedelta(days=retention_days)).isoformat()
        cursor = self._conn.cursor()
        cursor.execute("DELETE FROM tool_calls WHERE timestamp < ?", (cutoff,))
        self._conn.commit()
        deleted = cursor.rowcount
        if deleted > 0:
            logger.info(f"Purged {deleted} tool call logs older than {retention_days} days")
        return deleted

    # ── Lifecycle ────────────────────────────────────────────────────

    def close(self) -> None:
        """Clean up database connections."""
        self._conn.close()
        logger.info("Open Mythos connections closed.")
