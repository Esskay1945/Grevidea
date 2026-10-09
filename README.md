# Grevidea 🌿

**A green vision powered by intelligent ideas** — a full-stack sustainability platform that combines AI-driven climate intelligence, real-time tracking, civic engagement, and gamified rewards to help individuals and communities reduce their environmental footprint.

## Architecture

```
┌──────────────────┐     HTTPS/WS      ┌──────────────────────┐    Internal    ┌─────────────────────┐
│                  │ ◄──────────────── │                      │ ◄──────────── │                     │
│  Flutter App     │     :3000          │  Axum Gateway        │    :8000       │  GCI Brain          │
│  (Android/Web)   │ ────────────────► │  (Rust)              │ ────────────► │  (Python/FastAPI)   │
│                  │                    │                      │                │                     │
│  • Forest UI     │                    │  • 70+ REST routes   │                │  • LLM Fallback     │
│  • GPS tracking  │                    │  • WebSocket live    │                │    Gemini→Groq→     │
│  • Offline queue │                    │  • JWT auth          │                │    Ollama→Mistral   │
│  • 58 features   │                    │  • Delivery worker   │                │  • Tavily search    │
│                  │                    │  • PostGIS queries   │                │  • OpenAlex papers  │
└──────────────────┘                    └──────────┬───────────┘                │  • PDF corpus       │
                                                   │                            │  • SEAL loop        │
                                                   │                            │  • Mythos memory    │
                                                   ▼                            └─────────────────────┘
                                        ┌──────────────────────┐
                                        │  PostgreSQL + PostGIS │
                                        │  (Supabase or local)  │
                                        │                       │
                                        │  • 5 migration files  │
                                        │  • Spatial queries    │
                                        │  • Point ledger       │
                                        │  • Delivery queue     │
                                        └───────────────────────┘
```

### External Data Providers

| Provider | Purpose |
|---|---|
| [Open-Meteo](https://open-meteo.com/) | Weather forecasts, CAMS air quality, GloFAS flood model |
| [OSRM](https://project-osrm.org/) | Road routing (driving + walking) |
| [OpenStreetMap / Overpass](https://overpass-api.de/) | Rail/road geometry for transit inference |
| [Nominatim](https://nominatim.openstreetmap.org/) | Geocoding and reverse geocoding |
| [Open Food Facts](https://world.openfoodfacts.org/) | Product barcode + Agribalyse carbon data |
| [Tavily](https://tavily.com/) | Web search for AI fact-checking |
| [OpenAlex](https://openalex.org/) | Academic paper metadata and retrieval |

## Tech Stack

| Layer | Technology |
|---|---|
| **Mobile / Web** | Flutter (Dart) — `frontend/` |
| **API Gateway** | Rust / Axum — `backend/axum_gateway/` |
| **AI Brain** | Python / FastAPI — `backend/app/` |
| **Database** | PostgreSQL 16 + PostGIS |
| **CI** | GitHub Actions — `.github/workflows/ecosystem-audit.yml` |

## Features (58 tools)

Organized across 6 epics:

| Epic | Tools | Examples |
|---|---|---|
| **AI / Brain** | 8 | ClimateGPT, misinformation detector, nudge engine, eco persona, anxiety companion |
| **Carbon Footprint** | 10 | Calculator, food carbon, transport detection, supply chain, weekly report |
| **Marketplace** | 10 | EcoLens scanner, carbon credits, carpool, gig marketplace, green alternatives |
| **Civic** | 10 | AQI, pollution reports, RTI drafter, SOS, clean-air routing, municipal voting |
| **Gamification** | 10 | Points, achievements, streaks, squads, leaderboard, challenges, crowdfunding |
| **Platform** | 10 | Auth, profile, notifications, learning cards, admin, behavior analytics |

Full mapping: [`backend/tool-handler-map.json`](backend/tool-handler-map.json)
Flutter catalog: [`frontend/assets/feature_catalog.json`](frontend/assets/feature_catalog.json)

## Quick Start

### Prerequisites

- **Python 3.12+** — for GCI Brain
- **Rust (stable)** — for Axum Gateway
- **Flutter 3.10+** — for the mobile/web app
- **PostgreSQL 16 with PostGIS** — or a Supabase project

### 1. Database

```bash
# Apply migrations in filename order (note: two 002_* files, both required)
for migration in backend/axum_gateway/migrations/*.sql; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration"
done
```

### 2. GCI Brain (port 8000)

```bash
cd backend
cp .env.example .env       # Fill in at least one LLM provider key
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 3. Axum Gateway (port 3000)

```bash
cd backend/axum_gateway
cp .env.example .env       # Fill in DATABASE_URL, JWT_SECRET, BRAIN_URL
cargo run
```

### 4. Flutter App

```bash
cd frontend
flutter pub get

# Web (default localhost:3000 gateway)
flutter run -d chrome

# Android emulator (gateway at 10.0.2.2:3000)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Release APK for physical device
flutter build apk --dart-define=API_BASE_URL=https://your-gateway.example.com
```

## Configuration

Copy and fill in the `.env.example` files:
- **Brain**: [`backend/.env.example`](backend/.env.example) — LLM keys, research providers, PDF corpus path
- **Gateway**: [`backend/axum_gateway/.env.example`](backend/axum_gateway/.env.example) — database, JWT, routing, relays, feeds

> ⚠️ Never commit API keys or secrets. See the configuration tables in [`docs/integration-completion.md`](docs/integration-completion.md) for the full list.

### Optional: Research PDF Corpus

The project's 11 research papers are in `grevidea/Research Papers/`. To enable corpus-grounded AI answers:

```bash
# In backend/.env
RESEARCH_PDF_DIR=/path/to/grevidea/Research Papers
```

## Testing

```bash
# Brain (Python)
cd backend && PYTHONPATH=. pytest -q tests

# Gateway (Rust unit tests)
cd backend/axum_gateway && cargo test

# Flutter
cd frontend && flutter test

# Flutter release build
cd frontend && flutter build web --release
```

CI runs all three plus disposable PostGIS acceptance tests. See [`.github/workflows/ecosystem-audit.yml`](.github/workflows/ecosystem-audit.yml).

## Documentation

| Document | Purpose |
|---|---|
| [`docs/ecosystem-audit.md`](docs/ecosystem-audit.md) | Feature-by-feature acceptance results (PASS/FAIL/BLOCKED) and reproduction gates |
| [`docs/integration-completion.md`](docs/integration-completion.md) | Provider relay contracts, feed schemas, deployment verification steps |
| [`docs/deployment.md`](docs/deployment.md) | Production Docker, Supabase PostGIS setup, Nginx/Caddy proxy with WebSockets |
| [`docs/api-reference.md`](docs/api-reference.md) | REST and WebSocket API schemas and endpoint reference |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Contributor standards, testing guidelines, and PR verification |
| [`frontend/.env.example`](frontend/.env.example) | Flutter build configuration and `--dart-define` parameters |

## Civic Escalation & Emergency Helplines

The platform connects citizens directly to municipal authorities:

| Department / Desk | Contact Details | Mode in App |
|---|---|---|
| **General Civic Grievance #1** | `022-25331590` | Direct Phone Dialer |
| **General Civic Grievance #2** | `022-25331211` | Direct Phone Dialer |
| **Official Municipal Commissioner** | `mc@thanecity.gov.in` | **Direct In-App Email** (dispatched from app; no Gmail redirect) |
| **Regional Disaster Management Cell** | `1800222108` (Toll-Free 24x7) | 1-Tap SOS Helpline Dialer |


## Project Structure

```
Grevidea/
├── backend/
│   ├── app/
│   │   ├── brain/           # GCI Core Intelligence
│   │   │   ├── core.py      # Orchestrator — LLM fallback, subsystem init
│   │   │   ├── socratic.py  # Socratic reasoning interface
│   │   │   ├── seal.py      # SEAL loop (Sense-Evaluate-Act-Learn)
│   │   │   ├── mythos.py    # Long-term narrative memory
│   │   │   ├── amygdala.py  # System load monitoring / circuit breaker
│   │   │   ├── dreamer.py   # Background creative synthesis
│   │   │   ├── shadow.py    # Shadow simulation engine
│   │   │   ├── llm.py       # LLM provider abstraction
│   │   │   ├── research_corpus.py  # PDF ingestion + retrieval
│   │   │   └── tools/       # Brain-side tool definitions
│   │   ├── api/             # FastAPI routers
│   │   └── config.py        # Settings from environment
│   ├── axum_gateway/
│   │   ├── src/
│   │   │   ├── main.rs      # 70+ REST routes, WebSocket, delivery worker
│   │   │   ├── auth.rs      # JWT authentication middleware
│   │   │   ├── tools/       # Handler modules per epic
│   │   │   │   ├── civic.rs, footprint.rs, gamification.rs, ...
│   │   │   │   ├── delivery.rs    # Outbound relay + receipt worker
│   │   │   │   ├── live.rs        # Real-time location, weather, aid
│   │   │   │   ├── realtime.rs    # WebSocket + PostgreSQL LISTEN
│   │   │   │   ├── transit.rs     # Rail/road geometry matching
│   │   │   │   ├── hazards.rs     # Official authority alert adapter
│   │   │   │   └── air_stations.rs # PM2.5 station exposure scoring
│   │   │   └── models/
│   │   └── migrations/      # 001 → 004 SQL (PostGIS)
│   ├── tests/               # Pytest + acceptance scripts
│   └── tool-handler-map.json
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/            # Theme, network, widgets, location service
│   │   ├── features/        # 14 feature modules
│   │   └── state/           # AppState (ChangeNotifier)
│   ├── assets/              # feature_catalog.json
│   └── test/
├── grevidea/                 # Project documents + 11 research papers
├── docs/                     # Audit and integration docs
└── .github/workflows/       # CI pipeline
```

## Known Limitations

The system has 7 open FAIL items and multiple BLOCKED dependencies documented in [`docs/ecosystem-audit.md`](docs/ecosystem-audit.md). Key ones:

- **GPS**: No rail/highway map matching — high-speed travel needs user confirmation
- **Tracker**: Category history shows baseline shares, not full remote deltas
- **AQI Routing**: Uses CAMS forecasts, not real station readings (unless station feed configured)
- **SOS**: Stored distress request, not a dispatched emergency broadcast
- **EcoLens**: Incomplete lifecycle/recyclability coverage across all barcodes
- **AI**: No independent verification of peer review or factual correctness

See the full FAIL/BLOCKED tables and reproduction gates in the docs.

## License

Private project — not open source.

## Attribution

- [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
- [OSRM road routing](https://project-osrm.org/)
- [Open-Meteo](https://open-meteo.com/) weather, CAMS air quality, GloFAS flood model
- [Open Food Facts / Agribalyse](https://world.openfoodfacts.org/)
- [Tavily](https://tavily.com/) search
- [OpenAlex](https://openalex.org/) bibliographic metadata