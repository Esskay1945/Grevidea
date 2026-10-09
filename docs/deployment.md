# Grevidea Deployment & Operations Guide

This guide covers production deployment, infrastructure architecture, database setup, and reverse proxy configuration for the Grevidea ecosystem.

---

## 1. System Architecture

```mermaid
graph TD
    Client[📱 Flutter Client<br/>Android / iOS / Web]
    
    subgraph "Public Ingress (HTTPS & WSS)"
        Proxy[🛡️ Nginx / Caddy<br/>Reverse Proxy + TLS]
    end
    
    subgraph "Backend Services"
        Gateway[🦀 Axum Gateway :3000<br/>High-concurrency REST, WebSockets, Delivery Worker]
        Brain[🧠 FastAPI GCI Brain :8000<br/>AI Orchestration, Mythos Memory, SEAL Loop]
    end
    
    subgraph "Data Storage"
        DB[(🐘 PostgreSQL 16 + PostGIS 3.4<br/>Spatial indexing, Ledger, Outbox queue)]
        Memory[(📚 ChromaDB / SQLite<br/>Brain Mythos vector store)]
    end
    
    subgraph "External Providers & Relays"
        Weather[🌤️ Open-Meteo & CAMS<br/>Weather & Air Quality]
        Routing[🗺️ OSRM / Overpass<br/>Road & Pedestrian Routing]
        SMTP[📧 Municipal SMTP<br/>mc@thanecity.gov.in Direct Mail]
        Relays[🚨 Emergency & Municipal Relays<br/>SOS, RTI, Merchant fulfillment]
    end
    
    Client -->|HTTPS / WSS| Proxy
    Proxy -->|REST / WS| Gateway
    Gateway -->|Internal RPC| Brain
    Gateway -->|SQLx Connection Pool| DB
    Brain -->|Semantic Recall| Memory
    Gateway -->|Live Feed| Weather
    Gateway -->|Road Network| Routing
    Gateway -->|Direct Mail| SMTP
    Gateway -->|Signed Delivery Handoff| Relays
```

---

## 2. Docker & Container Deployment

### Production Docker Compose (`docker-compose.prod.yml`)

```yaml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:16-3.4
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-grevidea}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set strong database password}
      POSTGRES_DB: ${POSTGRES_DB:-grevidea_prod}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-grevidea}"]
      interval: 10s
      timeout: 5s
      retries: 5

  brain:
    build:
      context: ./backend
      dockerfile: Dockerfile.brain
    restart: always
    environment:
      PORT: 8000
      AXUM_GATEWAY_URL: http://gateway:3000
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      GEMINI_MODEL: ${GEMINI_MODEL:-gemini-3.8-flash}
      RESEARCH_PDF_DIR: /app/research_papers
    volumes:
      - ./grevidea/Research Papers:/app/research_papers:ro
      - brain_data:/app/data
    depends_on:
      postgres:
        condition: service_healthy

  gateway:
    build:
      context: ./backend/axum_gateway
      dockerfile: Dockerfile
    restart: always
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER:-grevidea}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-grevidea_prod}
      JWT_SECRET: ${JWT_SECRET:?Set 32+ byte random secret}
      BRAIN_URL: http://brain:8000
      PORT: 3000
      CIVIC_GRIEVANCE_EMAIL: mc@thanecity.gov.in
      SMTP_HOST: ${SMTP_HOST}
      SMTP_PORT: ${SMTP_PORT:-587}
      SMTP_USERNAME: ${SMTP_USERNAME}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      SMTP_FROM_EMAIL: ${SMTP_FROM_EMAIL:-grievance@grevidea.app}
      MUNICIPAL_SHELTER_FEED_URL: ${MUNICIPAL_SHELTER_FEED_URL}
      DELIVERY_CALLBACK_SECRET: ${DELIVERY_CALLBACK_SECRET}
    ports:
      - "127.0.0.1:3000:3000"
    depends_on:
      - brain
      - postgres

volumes:
  postgres_data:
  brain_data:
```

---

## 3. Database Migrations

Apply database migrations strictly in sequential order with `psql` and `ON_ERROR_STOP=1`:

```bash
export DATABASE_URL="postgres://user:password@host:5432/grevidea_prod"

# Ensure PostGIS extension is installed
psql "$DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Execute migrations in filename order
for file in backend/axum_gateway/migrations/*.sql; do
  echo "Applying migration: $file"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done
```

> **Note on Migration Order:** The repository contains migration files `001_initial.sql`, `002_*.sql`, `003_*.sql`, and `004_delivery_and_sync.sql`. Apply all files sequentially without skipping any version.

---

## 4. Reverse Proxy Setup (Caddy / Nginx)

The Axum Gateway serves both REST endpoints and real-time WebSocket subscriptions at `/api/v1/live`. The reverse proxy must support WebSocket upgrades and preserve authorization headers.

### Caddyfile (Automatic TLS via Let's Encrypt)

```caddyfile
api.grevidea.app {
    # Forward all API and WebSocket requests to Axum Gateway
    reverse_proxy 127.0.0.1:3000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }

    # Restrict Brain (port 8000) to internal network only; never expose directly to the internet
}
```

### Nginx Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name api.grevidea.app;

    ssl_certificate /etc/letsencrypt/live/api.grevidea.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.grevidea.app/privkey.pem;

    # Client payload size for photo attachments (up to 5MB)
    client_max_body_size 5M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        # WebSocket upgrade support for /api/v1/live
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Keepalive and timeouts
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```

---

## 5. Security & Secret Management

1. **JWT Secret:** Generate with `openssl rand -base64 32`. Rotate periodically by updating `JWT_SECRET` (existing tokens will expire and require user re-authentication).
2. **Delivery Callback HMAC:** Exchanged with external partner relays; must be at least 32 cryptographically secure random bytes.
3. **Internal Brain Isolation:** Port 8000 (Python FastAPI GCI) must never be bound to `0.0.0.0` or exposed publicly. It communicates strictly over `127.0.0.1` or the Docker private bridge network.
4. **CORS:** Production deployments should restrict `tower-http` CORS from `Any` to the production domain (`https://app.grevidea.app`).
5. **Direct Civic Grievance Email:** Configured via `SMTP_HOST`, `SMTP_PORT`, and `CIVIC_GRIEVANCE_EMAIL` (`mc@thanecity.gov.in`). If credentials are not present, grievance emails are safely recorded in `delivery_jobs` for queued relay.
