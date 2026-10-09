# Contributing to Grevidea

Thank you for contributing to Grevidea! This document outlines our code standards, test workflows, and PR verification procedures.

---

## 1. Development Environment

Grevidea consists of three interconnected layers:
1. **Frontend:** Flutter 3.10+ (Android, iOS, Web) in `frontend/`
2. **Gateway:** Rust / Axum on port 3000 in `backend/axum_gateway/`
3. **Brain:** Python 3.11+ / FastAPI on port 8000 in `backend/`

---

## 2. Running Local Tests

Before submitting a Pull Request, run all unit and integration test suites:

### Python Brain Tests
```bash
cd backend
$env:PYTHONPATH="." # PowerShell (or PYTHONPATH=. on Linux/macOS)
pytest -q tests
```

### Flutter Frontend Tests
```bash
cd frontend
flutter pub get
flutter test
flutter build web --release
```

### Axum Gateway Tests
```bash
cd backend/axum_gateway
cargo test --target x86_64-unknown-linux-gnu
```

---

## 3. Pull Request Guidelines

1. **Document Integrity:** Preserve existing comments and docstrings.
2. **No Invented Provider Data:** When an external API or key is absent, the system must return structured 503 or unavailable indicators—never fabricate mock scientific or hazard data.
3. **Idempotent Deliveries:** Any outbound dispatch (SOS, civic complaint, email, reward) must use deterministic idempotency keys and transactional database leases.
4. **Direct Civic Contacts:** Maintain official escalation helplines:
   - General Civic Grievance: `022-25331590` / `022-25331211`
   - Municipal Commissioner: `mc@thanecity.gov.in`
   - Regional Disaster Management Helpline: `1800222108`
