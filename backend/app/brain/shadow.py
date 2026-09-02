"""
Shadow Simulator — Digital Twin sandbox for testing brain-generated fixes.

Before GCI deploys a self-evolved fix (e.g., a new regex for parsing
an API response), it must survive testing in the shadows. Only fixes
that pass all test cases are promoted to production.
"""

from __future__ import annotations

import asyncio
import logging
import time
import traceback
import uuid
from typing import Any, Optional

from app.brain.models.schemas import BrainEvent, EventType, Severity, ShadowResult
from app.brain.mythos import OpenMythos
from app.config import Settings

logger = logging.getLogger("gci.shadow")


class ShadowSimulator:
    """
    Lightweight sandbox for testing brain-generated fixes.

    Workflow:
        1. Brain generates a potential fix (code string or function).
        2. Shadow runs the fix against saved test cases.
        3. If ALL test cases pass → promote to production.
        4. If ANY fail → reject and log the failure in the Mythos.
    """

    def __init__(self, settings: Settings, mythos: OpenMythos) -> None:
        self._settings = settings
        self._mythos = mythos
        self._results_history: list[ShadowResult] = []

    async def simulate(
        self,
        fix_code: str,
        test_cases: list[dict[str, Any]],
        fix_description: str = "Unnamed fix",
    ) -> ShadowResult:
        """
        Run a fix in an isolated execution context against test cases.

        Args:
            fix_code: Python code string defining the fix function.
                      Must define a function called `fix(input_data)`.
            test_cases: List of dicts with 'input' and 'expected_output' keys.
            fix_description: Human-readable description of what this fix does.

        Returns:
            ShadowResult with pass/fail outcome and details.
        """
        fix_id = f"fix_{uuid.uuid4().hex[:8]}"
        start = time.perf_counter()

        logger.info(f"Shadow simulation starting: {fix_id} — {fix_description}")

        # Validate minimum test cases
        if len(test_cases) < self._settings.shadow_min_test_cases:
            result = ShadowResult(
                fix_id=fix_id,
                fix_description=fix_description,
                test_cases_run=0,
                passed=False,
                error_message=(
                    f"Insufficient test cases: {len(test_cases)} provided, "
                    f"minimum {self._settings.shadow_min_test_cases} required."
                ),
            )
            self._log_result(result)
            return result

        passed = 0
        failed = 0
        errors: list[str] = []

        for i, test_case in enumerate(test_cases):
            try:
                success = await asyncio.wait_for(
                    self._run_test(fix_code, test_case),
                    timeout=self._settings.shadow_timeout_seconds,
                )
                if success:
                    passed += 1
                else:
                    failed += 1
                    errors.append(
                        f"Test case {i}: Output did not match expected."
                    )
            except asyncio.TimeoutError:
                failed += 1
                errors.append(f"Test case {i}: Timed out after "
                              f"{self._settings.shadow_timeout_seconds}s.")
            except Exception as e:
                failed += 1
                errors.append(f"Test case {i}: {str(e)}")

        latency = (time.perf_counter() - start) * 1000
        all_passed = failed == 0 and passed > 0

        result = ShadowResult(
            fix_id=fix_id,
            fix_description=fix_description,
            test_cases_run=passed + failed,
            test_cases_passed=passed,
            test_cases_failed=failed,
            passed=all_passed,
            error_message="; ".join(errors) if errors else None,
            latency_ms=round(latency, 2),
        )

        self._log_result(result)
        return result

    async def _run_test(
        self,
        fix_code: str,
        test_case: dict[str, Any],
    ) -> bool:
        """
        Execute a single test case in an isolated namespace.

        The fix_code must define a function `fix(input_data) -> output`.
        """
        # Create an isolated namespace for execution
        namespace: dict[str, Any] = {}

        try:
            # Execute the fix code in the isolated namespace
            exec(fix_code, namespace)  # noqa: S102 — intentional sandbox exec
        except Exception as e:
            raise RuntimeError(f"Fix code compilation failed: {e}") from e

        if "fix" not in namespace:
            raise RuntimeError(
                "Fix code must define a function called 'fix(input_data)'."
            )

        fix_fn = namespace["fix"]
        input_data = test_case.get("input", {})
        expected = test_case.get("expected_output")

        # Run the fix function
        result = fix_fn(input_data)

        # Compare output
        if expected is not None:
            return result == expected

        # If no expected output specified, just check it doesn't crash
        return True

    def _log_result(self, result: ShadowResult) -> None:
        """Log the simulation result to the Mythos."""
        self._results_history.append(result)

        event_type = EventType.SHADOW_PASS if result.passed else EventType.SHADOW_FAIL
        severity = Severity.INFO if result.passed else Severity.WARNING

        self._mythos.log_event(BrainEvent(
            event_type=event_type,
            severity=severity,
            source="shadow",
            message=(
                f"Shadow simulation {'PASSED' if result.passed else 'FAILED'}: "
                f"{result.fix_description} "
                f"({result.test_cases_passed}/{result.test_cases_run} tests passed)"
            ),
            data=result.model_dump(),
        ))

        # Store in semantic memory for future reference
        self._mythos.remember(
            text=(
                f"Shadow simulation for '{result.fix_description}': "
                f"{'PASSED' if result.passed else 'FAILED'}. "
                f"{result.test_cases_passed}/{result.test_cases_run} tests. "
                f"{result.error_message or 'No errors.'}"
            ),
            source="shadow",
            memory_type="fix",
            metadata={"fix_id": result.fix_id, "passed": result.passed},
        )

        logger.info(
            f"Shadow result: {result.fix_id} — "
            f"{'PASS' if result.passed else 'FAIL'} "
            f"({result.test_cases_passed}/{result.test_cases_run})"
        )

    async def promote(self, fix_id: str) -> bool:
        """
        Promote a successful fix to production.

        For the MVP, this just logs the promotion. In production, this
        would apply the fix to the live system (e.g., update a config,
        deploy a new parser, etc.).
        """
        result = next(
            (r for r in self._results_history if r.fix_id == fix_id),
            None,
        )

        if not result:
            logger.error(f"Fix {fix_id} not found in history.")
            return False

        if not result.passed:
            logger.error(f"Cannot promote failed fix {fix_id}.")
            return False

        self._mythos.log_event(BrainEvent(
            event_type=EventType.HEAL,
            source="shadow",
            message=f"Fix promoted to production: {result.fix_description}",
            data={"fix_id": fix_id},
        ))

        logger.info(f"Fix {fix_id} promoted: {result.fix_description}")
        return True

    async def reject(self, fix_id: str, reason: str) -> None:
        """Log a rejected fix and the reason for rejection."""
        self._mythos.log_event(BrainEvent(
            event_type=EventType.SHADOW_FAIL,
            severity=Severity.WARNING,
            source="shadow",
            message=f"Fix rejected: {fix_id}. Reason: {reason}",
            data={"fix_id": fix_id, "reason": reason},
        ))

        self._mythos.remember(
            text=f"Fix {fix_id} was rejected. Reason: {reason}. Do not retry this approach.",
            source="shadow",
            memory_type="fix",
            metadata={"fix_id": fix_id, "rejected": True},
        )

    @property
    def results_history(self) -> list[ShadowResult]:
        return list(self._results_history)
