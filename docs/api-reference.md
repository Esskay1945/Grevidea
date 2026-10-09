# Grevidea Gateway API Reference

The Axum Gateway exposes REST and WebSocket endpoints under `/api/v1/*` (port 3000). Most endpoints require a Bearer token in the `Authorization: Bearer <JWT>` header obtained via login or registration.

---

## 1. Authentication & Profile

### `POST /api/v1/auth/register`
Creates a new account and returns a signed JWT token.
- **Request:**
  ```json
  {"name": "Citizen Jane", "email": "jane@example.com", "password": "securepassword"}
  ```
- **Response:**
  ```json
  {"status": "ok", "token": "eyJhbGciOi...", "user": {"id": "UUID", "email": "jane@example.com", "name": "Citizen Jane"}}
  ```

### `POST /api/v1/auth/login`
Authenticates existing credentials.
- **Request:**
  ```json
  {"email": "jane@example.com", "password": "securepassword"}
  ```

---

## 2. Civic Accountability & Grievances (EPIC 4)

### `POST /api/v1/civic/email` *(NEW)*
Dispatches an official grievance email directly from the platform to the Municipal Commissioner (`mc@thanecity.gov.in`) without redirecting the user to Gmail or external mail apps.
- **Headers:** `Authorization: Bearer <JWT>`
- **Request:**
  ```json
  {
    "subject": "[Civic Grievance] Garbage Dumping at Ward 4, Majiwada",
    "message": "Overflowing waste container creating hygiene hazards near pillar #14.",
    "complaint_id": "TMC-SWM-2026",
    "waste_type": "Garbage Dumping",
    "location": "Majiwada Service Road Pillar #14",
    "latitude": 19.2183,
    "longitude": 72.9781,
    "photo_url": "data:image/jpeg;base64,...",
    "reporter_name": "Jane Citizen",
    "reporter_phone": "+91 9820000000",
    "recipient_email": "mc@thanecity.gov.in"
  }
  ```
- **Response:**
  ```json
  {
    "status": "ok",
    "data": {
      "success": true,
      "status": "delivered_smtp",
      "recipient": "mc@thanecity.gov.in",
      "dispatch_id": "b3e5a2c4-18df-4b92-94f8-112233445566",
      "complaint_id": "TMC-SWM-2026",
      "timestamp": "2026-10-09T03:30:00Z",
      "message": "Grievance email dispatched directly to Municipal Commissioner (mc@thanecity.gov.in)"
    }
  }
  ```

### `POST /api/v1/reports`
Submits a geotagged environmental pollution/waste complaint. Atomically enqueues a municipal delivery task and awards +25 green points.
- **Request:**
  ```json
  {
    "report_type": "Plastic Waste",
    "severity": 3,
    "description": "Unregulated single-use plastic dumping behind market",
    "latitude": 19.2183,
    "longitude": 72.9781,
    "photo_url": "data:image/jpeg;base64,..."
  }
  ```

### `GET /api/v1/reports`
Retrieves all historical complaints filed by the authenticated user.

### `POST /api/v1/sos`
Stores an emergency distress request with measured GPS coordinates, street address, needs inventory, and device battery level.
- **Request:**
  ```json
  {
    "disaster_type": "flood",
    "description": "Trapped on ground floor due to rising water",
    "needs": ["rescue", "water"],
    "people_count": 2,
    "latitude": 19.2183,
    "longitude": 72.9781,
    "battery_percent": 34,
    "street_address": "Opposite Talao Pali, Thane West"
  }
  ```

### `POST /api/v1/rti/draft`
Auto-generates a structured Right to Information (RTI) application compliant with Section 6 of the Indian RTI Act 2005.

### `GET /api/v1/aqi?city=Thane&lat=19.218&lon=72.978`
Returns live air quality indicators (US AQI, PM2.5, PM10) from CAMS/Open-Meteo or regional CPCB station networks.

---

## 3. Real-Time Telemetry & Feeds

### `GET /api/v1/live` (WebSocket)
WebSocket connection for real-time live events, trip logging, mutual-aid coordinate changes, and hazard alerts.
- **Protocol:** `Sec-WebSocket-Protocol: <JWT>`

### `GET /api/v1/weather?lat=19.2&lon=72.9`
Returns Open-Meteo forecast models (temperature, precipitation, 48-hour heatwave detection).

### `GET /api/v1/shelters?lat=19.2&lon=72.9&radius_km=5`
Returns verified municipal shelters from `MUNICIPAL_SHELTER_FEED_URL` with occupancy and distance.

### `GET /api/v1/hazards?lat=19.2&lon=72.9`
Returns official hazard warnings from the approved regional disaster authority feed and GloFAS river discharge context.

---

## 4. Footprint & Activities

### `GET /api/v1/baseline` & `POST /api/v1/baseline`
Manages the user's permanent lifestyle baseline (commute mode, diet, electricity, solar, household size).

### `POST /api/v1/activities` & `GET /api/v1/activities`
Synchronizes user activity logs with stable client UUIDs, idempotent retry support, and CO2 delta calculations.

---

## 5. Contact Helplines & Authorities

| Authority / Entity | Contact Details |
|---|---|
| **General Civic Grievance Helpline #1** | `022-25331590` |
| **General Civic Grievance Helpline #2** | `022-25331211` |
| **Official Municipal Commissioner Email** | `mc@thanecity.gov.in` |
| **Regional Disaster Management Cell Helpline** | `1800222108` (Toll-Free 24x7) |
