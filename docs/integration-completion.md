# Integration completion and activation guide

This change builds on PR #2 (`audit/ecosystem-repairs`). It provides working application/gateway workflows and provider contracts that can be activated later. A passing fixture test proves the contract and state transitions; it does not prove delivery to a real emergency authority or merchant. No real credentials are required to review this PR.

## What was added

| Area | Implemented behavior | Live acceptance dependency |
| --- | --- | --- |
| Travel capture | Account-scoped in-progress capture and completed-trip journal; original timestamps and stable IDs; acknowledge only after durable outbox enqueue | Android GPS/background/process-kill field test |
| Transit inference | Ordered hardware trace matched to OSM rail/road geometry; conservative rail auto-classification; ambiguous road/rail requires user choice | OSM coverage and real trip ground truth; bus versus car remains user-confirmed |
| Tracker | Shared baseline and Transport/Energy/Food/Waste events; monotonic onboarding completion; category totals and trends include dated deltas; existing gateway trips backfilled without re-awarding points | Multi-device and offline reconnect acceptance with deployed database |
| Carpool and mutual aid | Authenticated WebSocket snapshots on PostgreSQL notifications across replicas; GPS/radius filters; foreground polling fallback; true pedestrian route to pickup | Production WebSocket proxy configuration and route-provider capacity |
| Route air quality | Fresh PM2.5 station adapter; segment-distance integration, nearest station within 2 km, <=60-minute observations, >=80% coverage required for ranking; explicitly labeled CAMS fallback | Trusted municipal/OpenAQ adapter and adequate station coverage; estimates do not guarantee health safety |
| Hazards | Geofenced, issued/expiry-validated official alert adapter; unavailable status; separate GloFAS river-discharge model context | Approved regional authority feed; GloFAS is not a flash-flood warning |
| SOS | GPS/address/battery payload, consent-attested trusted contacts, transactional outbound queue, retry and signed receipt | Approved contact/dispatch relay and supported destination jurisdictions |
| Civic complaints | Structured report/photo/location persisted atomically with municipal delivery queue | Municipality adapter, recipient rules and acceptance reference |
| Rewards | Point debit and fulfillment queue in one transaction; delivery address for merchandise; signed fulfillment receipt; cancellation/refund before provider handoff | Merchant/NGO adapter and verified fulfillment evidence |
| Delivery center | Readiness, account-scoped statuses, receipts, retry, pre-handoff reward cancellation and trusted-contact CRUD | Provider credentials; readiness means configured, not independently certified |

Existing forest dimming, text contrast, animation lifecycle, dashboard layout, onboarding inputs, navigation, Gemini/Groq/Ollama fallback, Tavily/OpenAlex and scanner behavior are inherited from PR #2. No dashboard icons or text were repositioned in this follow-up.

## What to supply later

Set secrets in deployment settings or ignored `.env` files, never in a PR or chat message containing the values. Copy `backend/axum_gateway/.env.example` and `backend/.env.example` as templates.

| Component | Required configuration |
| --- | --- |
| Gateway | `DATABASE_URL` to PostgreSQL with PostGIS; random `JWT_SECRET`; `BRAIN_URL`; public HTTPS domain; Flutter `API_BASE_URL` |
| AI | At least one usable `GEMINI_API_KEY` + `GEMINI_MODEL`, `GROQ_API_KEY`, or running Ollama + installed model; optional Mistral |
| Research | `TAVILY_API_KEY`, `OPENALEX_API_KEY`; provide the requested 11 readable, licensed PDFs and set `RESEARCH_PDF_DIR` |
| SOS | `SOS_RELAY_URL`, `SOS_RELAY_TOKEN`; approved provider account, dispatch/contact destination rules |
| Municipal | `MUNICIPAL_RELAY_URL`, `MUNICIPAL_RELAY_TOKEN`; municipality endpoint/recipient jurisdiction and reference format |
| Rewards | `FULFILLMENT_RELAY_URL`, `FULFILLMENT_RELAY_TOKEN`; merchant/NGO account, catalog mapping and delivery policies |
| Receipts | Random `DELIVERY_CALLBACK_SECRET` (at least 32 bytes) exchanged with relays; public callback URL below |
| Official alerts | `HAZARD_FEED_URL`, `HAZARD_FEED_NAME`, optional `HAZARD_FEED_TOKEN`; normalized approved authority adapter |
| Stations | `AQI_STATION_FEED_URL`, optional `AQI_STATION_FEED_TOKEN`; fresh normalized station observations |
| Shelters | `MUNICIPAL_SHELTER_FEED_URL` trusted registry: `name`, `lat`, `lng`, `isOpen`, capacity/status |
| Routing | Production-capacity `OSRM_ROUTER_BASE`, separately prepared pedestrian `WALK_ROUTER_BASE`, `OVERPASS_URL`; public demonstration services have quotas |
| Release | Android signing configuration, Firebase configuration if push is enabled, physical Android device and authorized provider sandbox recipients |

A direct Twilio, government or merchant API is not interchangeable with the relay contract below. Deploy an adapter to translate this contract to your chosen partner's API. API credentials alone cannot authorize emergency dispatch, establish municipal acceptance or verify tree planting.

## Outbound relay contract

Gateway sends HTTPS POST with `Authorization: Bearer <relay token>` and `Idempotency-Key: <delivery UUID>`. Request:

```json
{"schema_version":1,"delivery_id":"UUID","entity_id":"UUID","kind":"sos|civic|reward","payload":{}}
```

SOS payload includes measured location, battery/address when supplied and consent-attested trusted contacts. Civic payload includes the structured complaint and attachment. Reward payload includes catalog reward ID and optional address/phone. Treat these as sensitive user data; redact request bodies and authorization headers from logs. A provider must enforce durable idempotency on delivery ID before sending anything or placing an order.

Return 2xx JSON `{"provider_id":"stable-provider-reference"}` only after accepting the work. Gateway marks **accepted**, not delivered. Network failures/non-2xx retry with bounded exponential backoff; eight attempts enter `dead_letter`. Workers claim PostgreSQL row leases with `SKIP LOCKED`. A crash retries the same idempotency key. Missing configuration marks **blocked** and automatically retries after configuration is supplied.

Partner POSTs to `/integrations/delivery/receipt`:

```json
{"event_id":"unique-provider-event","delivery_id":"UUID","provider_id":"stable-provider-reference","status":"delivered","details":{"authority_reference":"reference","evidence_url":"https://partner.example/receipt"}}
```

`status` accepts `delivered` or `failed`. Define delivered as an actual recipient acceptance/fulfillment receipt, not request creation. Reward delivered changes its redemption to fulfilled. Callback headers: `x-grevidea-timestamp` is Unix seconds; `x-grevidea-signature` is lowercase hex HMAC-SHA256 of `timestamp + "." + exact raw request body`, keyed by `DELIVERY_CALLBACK_SECRET`. Five-minute replay window, signature checking and event-ID deduplication apply. Delivered jobs cannot regress. Send the callback after the acceptance response whenever possible; a callback racing the HTTP response is supported while the job has a processing lease. A provider's own evidentiary trust remains an operational requirement.

Pending rewards can be cancelled/refunded via `/api/v1/rewards/{redemption_id}/cancel` only before provider handoff. Processing, accepted or fulfilled requests require partner resolution; the app never assumes it can undo a real order. Cancellation is idempotent and refunds once.

## Feed contracts

Authority adapter responds to GET `?lat=...&lon=...` with up to 1,000 alerts:

```json
[{"id":"authority-warning","kind":"flash_flood","title":"Flood warning","description":"Issuing authority instructions","severity":"Warning","bounds":[72,19,74,20],"issued_at":"2026-10-09T00:00:00Z","expires_at":"2026-10-09T06:00:00Z","source_url":"https://authority.example/warning"}]
```

Kinds: flood, flash_flood, heat, air_quality, storm. Bounds are west/south/east/north, including antimeridian support. Expired, future-issued, malformed or out-of-area alerts are excluded. An empty feed never establishes safety. Use adapters with the authority's authorized provenance and renewal schedule.

Station adapter responds with up to 2,000 observations covering the requested city's route area:

```json
[{"station_id":"municipal-01","latitude":19.2,"longitude":72.9,"pm2_5_ug_m3":12.5,"measured_at":"2026-10-09T01:00:00Z"}]
```

Values are concentration in micrograms per cubic meter, not AQI indices. Route mean and distance integral estimate spatial concentration; no claim of inhaled dose or universally safest route. Stale/missing coverage does not receive a made-up score. CAMS fallback is labeled separately. Metro/bus/car/EV comparison remains a carbon estimate on road distance, not a live timetable or transit itinerary.

## Deploy and verify

1. Back up the database. Apply new migration `004_delivery_and_sync.sql` after migrations already used by PR #2. Fresh installations apply all files in filename order with `psql -v ON_ERROR_STOP=1`; the repository has two different 002 files, so do not silently skip either. Never reapply old schema migrations blindly to an existing production DB.
2. Start Brain on port 8000 and gateway on 3000. Restrict Brain to the private service network. Configure HTTPS and WebSocket upgrades; pass Authorization and `Sec-WebSocket-Protocol` without logging credentials. PostgreSQL LISTEN must use a direct/session connection rather than a transaction-only pooler.
3. Run `PYTHONPATH=. pytest -q tests` in backend, `cargo test --target x86_64-unknown-linux-gnu` in gateway, and `flutter test` plus `flutter build web --release` in frontend. CI also migrates disposable PostGIS and runs `gateway_acceptance.py` and `completion_acceptance.py` against **local-only** provider fixtures.
4. In a staging deployment, verify cross-device baseline/history, offline reconnect and no duplicate points, carpool seat races, mutual-aid push, signed receipt failure/replay, queue recovery after worker crash and rejected provider request. Inspect Delivery Center for blocked/accepted/delivered distinctions.
5. On physical Android, test one-time permissions, background/minimized tracking, stationary periods, battery usage, process kill and restore, rail/road ambiguity, revocation, camera, barcode and battery reading. Zero battery drain is not a feasible hardware guarantee. Foreground tracking has a visible Android notification; silent permission reuse does not mean hidden tracking.
6. With authorized sandbox destinations, test each real provider and retain actual references. Test a source-backed AI answer, Tavily query, OpenAlex retrieval and supplied PDF grounding. Independently assess supporting sources and model accuracy.

No Android SDK/device, live provider accounts, approved municipal/dispatch adapter, authority feed, station feed or 11-paper corpus were available for this build. Tree survival photo verification, independently certified lifecycle data for every barcode, and real public-transit timetable routing are not created by configuring a generic API key. Self-reported trees award no verified carbon/points. Those require separately defined provider evidence and data coverage. Release acceptance must record them as blocked until those integrations and device tests are supplied, rather than claim 100% operational coverage.

References: [FOSSGIS routing service](https://map.project-osrm.org/about.html), [Open-Meteo flood model documentation](https://open-meteo.com/en/docs/flood-api), [OSRM API](https://project-osrm.org/docs/v5.24.0/api/).
