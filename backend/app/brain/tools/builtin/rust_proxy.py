"""
GCI Rust Tool Proxies — Registers all 58 Axum gateway tools in the Brain.

When the LLM Orchestrator calls a "tool", it actually calls one of these proxies.
The proxy fires an HTTP request to the Rust Axum gateway (/internal/tools/NAME)
and returns the result. The LLM has zero knowledge that the tool runs in Rust.

Architecture:
  LLM → RustToolProxy.execute() → POST axum_gateway/internal/tools/{name} → Rust fn
"""

from __future__ import annotations
import httpx
import logging
from typing import Any
from app.brain.tools.base import BaseTool
from app.config import get_settings

logger = logging.getLogger("gci.tools.rust_proxy")


class RustToolProxy(BaseTool):
    """
    Generic proxy that forwards tool calls to the Rust Axum gateway.
    The LLM sees this exactly like any other Python tool.
    """

    def __init__(
        self,
        tool_name: str = "",
        tool_description: str = "",
        tool_parameters: dict | None = None,
        critical: bool = False,
        axum_path: str | None = None,
    ) -> None:
        self._name = tool_name
        self._description = tool_description
        self._parameters = tool_parameters or {"type": "object", "properties": {}, "required": []}
        self._critical = critical
        self._axum_path = axum_path or f"/internal/tools/{tool_name}"

    @property
    def name(self) -> str:
        return self._name

    @property
    def description(self) -> str:
        return self._description

    @property
    def parameters(self) -> dict:
        return self._parameters

    @property
    def is_critical(self) -> bool:
        return self._critical

    async def execute(self, **kwargs: Any) -> dict[str, Any]:
        """
        Forward the tool call to the Rust Axum gateway.
        The gateway handles the actual business logic.
        """
        settings = get_settings()
        gateway_url = getattr(settings, "axum_gateway_url", "http://localhost:3000")
        url = f"{gateway_url}{self._axum_path}"

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, json=kwargs)
                resp.raise_for_status()
                return resp.json()
        except httpx.ConnectError:
            logger.warning(f"Axum gateway unreachable for tool '{self.name}'. Gateway may be offline.")
            return {
                "success": False,
                "error": "Gateway offline — running in Brain-only mode",
                "tool": self.name,
                "fallback": True,
            }
        except Exception as e:
            logger.error(f"Rust proxy error for tool '{self.name}': {e}")
            return {"success": False, "error": str(e), "tool": self.name}


# ── Complete 58 Feature Tool Proxies Grouped by Epic ─────────────────────────

ALL_RUST_PROXIES: list[RustToolProxy] = [

    # ════ EPIC 1: Grevidea Core Intelligence (T01–T08) ═════════════════════════
    RustToolProxy(
        tool_name="climate_gpt",
        tool_description="Verified RAG-based climate reasoning chatbot engine. Answers user climate and sustainability inquiries citing verified peer-reviewed climate data.",
        tool_parameters={
            "type": "object",
            "properties": {
                "message": {"type": "string", "description": "The user query or prompt"},
                "mode": {"type": "string", "enum": ["direct", "socratic"], "default": "direct"},
            },
            "required": ["message"],
        },
        critical=True,
        axum_path="/internal/tools/climate_gpt",
    ),
    RustToolProxy(
        tool_name="misinformation_detector",
        tool_description="Detect, fact-check, and scientifically debunk climate misinformation and fake claims using verified peer-reviewed climate literature.",
        tool_parameters={
            "type": "object",
            "properties": {"claim": {"type": "string", "description": "The climate claim or statement to fact-check"}},
            "required": ["claim"],
        },
        axum_path="/internal/tools/misinformation_detector",
    ),
    RustToolProxy(
        tool_name="jitai_nudge_engine",
        tool_description="Just-In-Time Adaptive Intervention (JITAI) engine. Generates hyper-contextual behavioral nudges timed to the user's active environment, streak, and commute state.",
        tool_parameters={
            "type": "object",
            "properties": {"context": {"type": "object", "description": "User context payload: location, timestamp, streak, transit mode"}},
            "required": ["context"],
        },
        axum_path="/internal/tools/jitai_nudge_engine",
    ),
    RustToolProxy(
        tool_name="spillover_analyzer",
        tool_description="Analyzes behavioral spillover across user eco-action domains (e.g., whether cycling adoption drives plant-based diet transitions) using Open Mythos memory.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "days": {"type": "integer", "default": 30}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/spillover_analyzer",
    ),
    RustToolProxy(
        tool_name="disaster_risk_predictor",
        tool_description="Hyperlocal AI disaster and climate risk predictor. Cross-references citizen environmental degradation reports (e.g. choked drainage, illegal deforestation) with meteorological patterns to forecast urban flood and heat risks.",
        tool_parameters={
            "type": "object",
            "properties": {
                "city": {"type": "string"},
                "lat": {"type": "number"},
                "lon": {"type": "number"},
            },
            "required": ["city"],
        },
        critical=True,
        axum_path="/internal/tools/disaster_risk_predictor",
    ),
    RustToolProxy(
        tool_name="eco_persona_generator",
        tool_description="Synthesizes user behavioral telemetry from Open Mythos to create an evolving Eco Persona profile with archetypes, strengths, and personalized growth vectors.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/eco_persona_generator",
    ),
    RustToolProxy(
        tool_name="morning_brief_composer",
        tool_description="Composes the daily morning AI briefing synthesizing yesterday's CO2 performance, current hyperlocal AQI, top daily quest, and motivational history insights.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/morning_brief_composer",
    ),
    RustToolProxy(
        tool_name="climate_anxiety_companion",
        tool_description="Empathetic climate anxiety psychological companion offering validation, evidence-based grounding techniques, and constructive agency-driven action plans.",
        tool_parameters={
            "type": "object",
            "properties": {
                "feeling": {"type": "string"},
                "intensity": {"type": "integer", "minimum": 1, "maximum": 10},
            },
            "required": ["feeling"],
        },
        axum_path="/internal/tools/climate_anxiety_companion",
    ),

    # ════ EPIC 2: Automated Footprint & Lifestyle Telemetry (T09–T18) ═══════════
    RustToolProxy(
        tool_name="carbon_calculator",
        tool_description="Deterministic transport carbon calculator. Computes exact CO2 emitted, CO2 avoided vs car baseline, and Green Points earned.",
        tool_parameters={
            "type": "object",
            "properties": {
                "mode": {"type": "string", "enum": ["car","bus","train","metro","cycle","walk","flight","motorbike","ev_car"]},
                "distance_km": {"type": "number"},
                "passengers": {"type": "integer", "default": 1},
            },
            "required": ["mode", "distance_km"],
        },
        critical=True,
        axum_path="/internal/tools/carbon_calculator",
    ),
    RustToolProxy(
        tool_name="transport_mode_detector",
        tool_description="Infers user transportation mode from Android GPS speeds, accelerometer cadence, and cell tower transition velocities.",
        tool_parameters={
            "type": "object",
            "properties": {"speed_kmh": {"type": "number"}, "cadence_spm": {"type": "number"}},
            "required": ["speed_kmh"],
        },
        axum_path="/internal/tools/transport_mode_detector",
    ),
    RustToolProxy(
        tool_name="carbon_history",
        tool_description="Queries historical carbon logs and trends for a user across custom day intervals.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "days": {"type": "integer", "default": 30}},
            "required": ["user_id"],
        },
        critical=True,
        axum_path="/internal/tools/carbon_history",
    ),
    RustToolProxy(
        tool_name="carbon_budget",
        tool_description="Manages personal monthly carbon allowance caps, tracking consumption velocity and breach warnings.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "monthly_cap_kg": {"type": "number"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/carbon_budget",
    ),
    RustToolProxy(
        tool_name="food_carbon",
        tool_description="Calculates farm-to-table carbon and embedded water footprint for food items, recipes, and ingredients.",
        tool_parameters={
            "type": "object",
            "properties": {
                "food_name": {"type": "string"},
                "quantity_grams": {"type": "number"},
                "origin": {"type": "string", "enum": ["local", "imported", "unknown"]},
            },
            "required": ["food_name", "quantity_grams"],
        },
        axum_path="/internal/tools/food_carbon",
    ),
    RustToolProxy(
        tool_name="supply_chain_tracer",
        tool_description="Traces multi-tier supply chain footprints and transport mileage for commercial products and commodities.",
        tool_parameters={
            "type": "object",
            "properties": {"product_sku": {"type": "string"}, "barcode": {"type": "string"}},
            "required": [],
        },
        axum_path="/internal/tools/supply_chain_tracer",
    ),
    RustToolProxy(
        tool_name="lifestyle_auto_inferrer",
        tool_description="Passively aggregates biometric and activity telemetry from Google Health Connect / Apple Health to auto-log green actions.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "step_count": {"type": "integer"}, "active_minutes": {"type": "integer"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/lifestyle_auto_inferrer",
    ),
    RustToolProxy(
        tool_name="health_planet_correlator",
        tool_description="Correlates planetary carbon reductions with human biometric health improvements (resting heart rate, cardiovascular capacity).",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/health_planet_correlator",
    ),
    RustToolProxy(
        tool_name="weekly_carbon_report",
        tool_description="Synthesizes weekly narrative progress digests with domain-by-domain emissions reductions and behavioral highlights.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/weekly_carbon_report",
    ),
    RustToolProxy(
        tool_name="carbon_comparison",
        tool_description="Benchmarks user emissions against city, national, and global percentiles with peer ranking insights.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/carbon_comparison",
    ),

    # ════ EPIC 3: Sustainable Marketplaces & Circular Economy (T19–T28) ═════════
    RustToolProxy(
        tool_name="carbon_cap_market",
        tool_description="P2P personal carbon trading simulation engine. Facilitates micro-credit exchange between low and high emitters.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "action": {"type": "string", "enum": ["buy", "sell", "list"]}},
            "required": ["user_id", "action"],
        },
        axum_path="/internal/tools/carbon_cap_market",
    ),
    RustToolProxy(
        tool_name="ecolens_scanner",
        tool_description="CV and barcode sustainability scanner. Retrieves lifecycle footprint and eco-certification ratings for scanned items.",
        tool_parameters={
            "type": "object",
            "properties": {"barcode": {"type": "string"}},
            "required": ["barcode"],
        },
        axum_path="/internal/tools/ecolens_scanner",
    ),
    RustToolProxy(
        tool_name="resource_pool_manager",
        tool_description="Hyperlocal anti-consumption borrow/lend engine for sharing heavy tools, appliances, and gear among neighbors.",
        tool_parameters={
            "type": "object",
            "properties": {"listing_id": {"type": "string"}, "borrower_id": {"type": "string"}},
            "required": ["listing_id", "borrower_id"],
        },
        axum_path="/internal/tools/resource_pool_manager",
    ),
    RustToolProxy(
        tool_name="green_gig_marketplace",
        tool_description="Community marketplace for green freelance gigs, repair cafes, urban gardening labor, and solar installs.",
        tool_parameters={
            "type": "object",
            "properties": {"city": {"type": "string"}, "skills": {"type": "array", "items": {"type": "string"}}},
            "required": [],
        },
        axum_path="/internal/tools/green_gig_marketplace",
    ),
    RustToolProxy(
        tool_name="carpool_matcher",
        tool_description="Matches verified commuters along shared routes, calculating per-rider emissions reductions and shared credits.",
        tool_parameters={
            "type": "object",
            "properties": {"origin": {"type": "string"}, "destination": {"type": "string"}},
            "required": ["origin", "destination"],
        },
        axum_path="/internal/tools/carpool_matcher",
    ),
    RustToolProxy(
        tool_name="offset_suggester",
        tool_description="Recommends verified, audited local carbon offset and afforestation projects with transparent fund utilization.",
        tool_parameters={
            "type": "object",
            "properties": {"target_co2_kg": {"type": "number"}},
            "required": ["target_co2_kg"],
        },
        axum_path="/internal/tools/offset_suggester",
    ),
    RustToolProxy(
        tool_name="green_product_recommender",
        tool_description="Recommends lower-carbon, plastic-free alternatives for high-impact household and consumer goods.",
        tool_parameters={
            "type": "object",
            "properties": {"category": {"type": "string"}},
            "required": ["category"],
        },
        axum_path="/internal/tools/green_product_recommender",
    ),
    RustToolProxy(
        tool_name="marketplace_impact_calc",
        tool_description="Calculates cumulative avoided manufacturing and packaging emissions from circular marketplace transactions.",
        tool_parameters={
            "type": "object",
            "properties": {"item_category": {"type": "string"}},
            "required": ["item_category"],
        },
        axum_path="/internal/tools/marketplace_impact_calc",
    ),
    RustToolProxy(
        tool_name="verified_seller_auditor",
        tool_description="Audits green credentials and verifies environmental certifications for sustainable marketplace vendors.",
        tool_parameters={
            "type": "object",
            "properties": {"vendor_id": {"type": "string"}},
            "required": ["vendor_id"],
        },
        axum_path="/internal/tools/verified_seller_auditor",
    ),
    RustToolProxy(
        tool_name="circular_economy_tracker",
        tool_description="Tracks platform-wide circular velocity, total items diverted from landfills, and embodied carbon conserved.",
        tool_parameters={
            "type": "object",
            "properties": {},
            "required": [],
        },
        axum_path="/internal/tools/circular_economy_tracker",
    ),

    # ════ EPIC 4: Civic Accountability & Disaster Resilience (T29–T38) ══════════
    RustToolProxy(
        tool_name="aqi_fetcher",
        tool_description="Real-time Air Quality Index fetcher from CPCB (India) and OpenAQ with particulate breakdown (PM2.5, PM10, NO2).",
        tool_parameters={
            "type": "object",
            "properties": {"city": {"type": "string"}, "lat": {"type": "number"}, "lon": {"type": "number"}},
            "required": [],
        },
        critical=True,
        axum_path="/internal/tools/aqi_fetcher",
    ),
    RustToolProxy(
        tool_name="aqi_heatmap_generator",
        tool_description="Generates PostGIS spatial vector tiles representing hyperlocal air quality heatmaps across urban sectors.",
        tool_parameters={
            "type": "object",
            "properties": {"city": {"type": "string"}, "bbox": {"type": "array", "items": {"type": "number"}}},
            "required": ["city"],
        },
        axum_path="/internal/tools/aqi_heatmap_generator",
    ),
    RustToolProxy(
        tool_name="pollution_reporter",
        tool_description="Submits geotagged citizen pollution and open waste reports, generating verifiable civic records.",
        tool_parameters={
            "type": "object",
            "properties": {
                "user_id": {"type": "string"},
                "latitude": {"type": "number"},
                "longitude": {"type": "number"},
                "report_type": {"type": "string"},
                "severity": {"type": "integer"},
            },
            "required": ["user_id", "latitude", "longitude", "report_type"],
        },
        axum_path="/internal/tools/pollution_reporter",
    ),
    RustToolProxy(
        tool_name="pollution_source_mapper",
        tool_description="Spatial clustering engine that aggregates individual citizen reports into attributed industrial and civic pollution sources.",
        tool_parameters={
            "type": "object",
            "properties": {"city": {"type": "string"}},
            "required": ["city"],
        },
        axum_path="/internal/tools/pollution_source_mapper",
    ),
    RustToolProxy(
        tool_name="green_zone_finder",
        tool_description="Spatial query tool that discovers urban parks, tree canopies, and low-PM2.5 clean air refuge zones.",
        tool_parameters={
            "type": "object",
            "properties": {"lat": {"type": "number"}, "lon": {"type": "number"}, "radius_km": {"type": "number"}},
            "required": ["lat", "lon"],
        },
        axum_path="/internal/tools/green_zone_finder",
    ),
    RustToolProxy(
        tool_name="rti_drafter",
        tool_description="Auto-drafts formal applications under India's Right to Information Act 2005 for civic and environmental violations.",
        tool_parameters={
            "type": "object",
            "properties": {
                "user_id": {"type": "string"},
                "violation_type": {"type": "string"},
                "authority": {"type": "string"},
                "location": {"type": "string"},
            },
            "required": ["user_id", "violation_type", "authority", "location"],
        },
        axum_path="/internal/tools/rti_drafter",
    ),
    RustToolProxy(
        tool_name="municipal_budget_voter",
        tool_description="Participatory civic voting platform for allocating municipal green infrastructure and climate resilience funds.",
        tool_parameters={
            "type": "object",
            "properties": {"ward_id": {"type": "string"}, "project_id": {"type": "string"}},
            "required": ["ward_id", "project_id"],
        },
        axum_path="/internal/tools/municipal_budget_voter",
    ),
    RustToolProxy(
        tool_name="disaster_sos",
        tool_description="Emergency mutual-aid SOS dispatcher matching affected citizens with nearest volunteer responders and rescue supplies during climate crises.",
        tool_parameters={
            "type": "object",
            "properties": {
                "user_id": {"type": "string"},
                "latitude": {"type": "number"},
                "longitude": {"type": "number"},
                "disaster_type": {"type": "string"},
                "needs": {"type": "array", "items": {"type": "string"}},
            },
            "required": ["user_id", "latitude", "longitude", "disaster_type"],
        },
        critical=True,
        axum_path="/internal/tools/disaster_sos",
    ),
    RustToolProxy(
        tool_name="route_aqi_scorer",
        tool_description="Scores multi-modal commute routes based on integrated real-time air pollution exposure.",
        tool_parameters={
            "type": "object",
            "properties": {"waypoints": {"type": "array", "items": {"type": "array", "items": {"type": "number"}}}},
            "required": ["waypoints"],
        },
        axum_path="/internal/tools/route_aqi_scorer",
    ),
    RustToolProxy(
        tool_name="health_impact_explainer",
        tool_description="Translates complex environmental sensor telemetry into plain-language health guidance for vulnerable demographics.",
        tool_parameters={
            "type": "object",
            "properties": {"aqi": {"type": "integer"}, "user_age": {"type": "integer"}},
            "required": ["aqi"],
        },
        axum_path="/internal/tools/health_impact_explainer",
    ),

    # ════ EPIC 5: Behavioral Gamification & Community (T39–T48) ═════════════════
    RustToolProxy(
        tool_name="green_points",
        tool_description="Ledger query for user Green Points balance, tier standing, and relative leaderboard rank.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        critical=True,
        axum_path="/internal/tools/green_points",
    ),
    RustToolProxy(
        tool_name="points_ledger",
        tool_description="Audited double-entry ledger that records all earned, spent, and transferred Green Points transactions.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "delta": {"type": "integer"}, "reason": {"type": "string"}},
            "required": ["user_id", "delta", "reason"],
        },
        critical=True,
        axum_path="/internal/tools/points_ledger",
    ),
    RustToolProxy(
        tool_name="achievement_engine",
        tool_description="Deterministic badge unlock engine that evaluates milestone criteria and grants achievements.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/achievement_engine",
    ),
    RustToolProxy(
        tool_name="leaderboard",
        tool_description="High-performance paginated global and neighborhood leaderboard ranking users by Green Points and lifetime CO2 saved.",
        tool_parameters={
            "type": "object",
            "properties": {"page": {"type": "integer", "default": 1}, "limit": {"type": "integer", "default": 20}},
            "required": [],
        },
        axum_path="/internal/tools/leaderboard",
    ),
    RustToolProxy(
        tool_name="streak_tracker",
        tool_description="Maintains daily eco-action streaks, calculating longest historical records and next milestone rewards.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/streak_tracker",
    ),
    RustToolProxy(
        tool_name="eco_squad_manager",
        tool_description="Manages cooperative Eco Squad groups, team quests, member leaderboards, and shared impact goals.",
        tool_parameters={
            "type": "object",
            "properties": {"name": {"type": "string"}, "created_by": {"type": "string"}},
            "required": ["name", "created_by"],
        },
        axum_path="/internal/tools/eco_squad_manager",
    ),
    RustToolProxy(
        tool_name="challenge_generator",
        tool_description="Generates personalized weekly climate quests adapted to user transit habits and lifestyle preferences.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/challenge_generator",
    ),
    RustToolProxy(
        tool_name="impact_translator",
        tool_description="Translates abstract CO2 kilogram metrics into relatable real-world equivalents (tree-days, car-km avoided, smartphone recharges).",
        tool_parameters={
            "type": "object",
            "properties": {"co2_saved_kg": {"type": "number"}},
            "required": ["co2_saved_kg"],
        },
        axum_path="/internal/tools/impact_translator",
    ),
    RustToolProxy(
        tool_name="green_social_feed",
        tool_description="Social feed of verified eco-actions, community milestones, and sustainability stories.",
        tool_parameters={
            "type": "object",
            "properties": {"page": {"type": "integer", "default": 1}},
            "required": [],
        },
        axum_path="/internal/tools/green_social_feed",
    ),
    RustToolProxy(
        tool_name="crowdfunding_manager",
        tool_description="Manages civic green infrastructure crowdfunding campaigns (solar pumps, school gardens, composting plants).",
        tool_parameters={
            "type": "object",
            "properties": {"title": {"type": "string"}, "goal_points": {"type": "integer"}},
            "required": ["title", "goal_points"],
        },
        axum_path="/internal/tools/crowdfunding_manager",
    ),

    # ════ EPIC 6: User, Platform & Infrastructure (T49–T58) ═════════════════════
    RustToolProxy(
        tool_name="user_profile",
        tool_description="Manages user account identity, privacy preferences, notification toggles, and eco-persona metadata.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        critical=True,
        axum_path="/internal/tools/user_profile",
    ),
    RustToolProxy(
        tool_name="auth_manager",
        tool_description="Issues, validates, and revokes JWT bearer tokens and password credentials with secure bcrypt hashing.",
        tool_parameters={
            "type": "object",
            "properties": {"email": {"type": "string"}},
            "required": ["email"],
        },
        critical=True,
        axum_path="/internal/tools/auth_manager",
    ),
    RustToolProxy(
        tool_name="notification_sender",
        tool_description="Dispatches push notifications (FCM for Android) for quest reminders, AQI alerts, and squad milestones.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "title": {"type": "string"}, "body": {"type": "string"}},
            "required": ["user_id", "title", "body"],
        },
        axum_path="/internal/tools/notification_sender",
    ),
    RustToolProxy(
        tool_name="nudge_scheduler",
        tool_description="Schedules time-sensitive behavioral nudges and notification deliveries based on user activity windows.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "cron_pattern": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/nudge_scheduler",
    ),
    RustToolProxy(
        tool_name="social_graph_manager",
        tool_description="Manages user social connections, followers, followings, and friend activity feeds.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "target_id": {"type": "string"}},
            "required": ["user_id", "target_id"],
        },
        axum_path="/internal/tools/social_graph_manager",
    ),
    RustToolProxy(
        tool_name="privacy_manager",
        tool_description="Handles GDPR data exports, consent settings, and right-to-be-forgotten irreversible account deletions.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}, "action": {"type": "string", "enum": ["export", "delete"]}},
            "required": ["user_id", "action"],
        },
        axum_path="/internal/tools/privacy_manager",
    ),
    RustToolProxy(
        tool_name="behavior_analyzer",
        tool_description="Machine learning clustering module detecting habitual user transit, consumption, and sustainability trends.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/behavior_analyzer",
    ),
    RustToolProxy(
        tool_name="anomaly_explainer",
        tool_description="Explains anomalies in system vitals, sudden spikes in community pollution reports, or unexpected emissions dips.",
        tool_parameters={
            "type": "object",
            "properties": {"anomaly_data": {"type": "object"}},
            "required": ["anomaly_data"],
        },
        axum_path="/internal/tools/anomaly_explainer",
    ),
    RustToolProxy(
        tool_name="learning_cards",
        tool_description="Delivers bite-sized micro-learning climate flashcards with interactive comprehension quizzes and point rewards.",
        tool_parameters={
            "type": "object",
            "properties": {"user_id": {"type": "string"}},
            "required": ["user_id"],
        },
        axum_path="/internal/tools/learning_cards",
    ),
    RustToolProxy(
        tool_name="admin_override",
        tool_description="Super-admin intervention panel providing manual system resets, tool enablement overrides, and survival controls.",
        tool_parameters={
            "type": "object",
            "properties": {"action": {"type": "string"}},
            "required": ["action"],
        },
        critical=True,
        axum_path="/internal/tools/admin_override",
    ),
]
