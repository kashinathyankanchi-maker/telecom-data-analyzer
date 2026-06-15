# Telecom Data Analyzer

A secure, cross-platform telecom record analysis platform built with **Flutter** (Android + Windows) and **Python FastAPI**.

---

## Features

| Feature | Description |
|---|---|
| **Data Ingestion** | Upload CDR, SDR, TDR CSV files with automatic column mapping |
| **Global Search** | Search by phone number or IMEI — subscriber profile + call log |
| **Link Analysis** | Force-directed contact graph with pinch-to-zoom and node details |
| **Geo Mapping** | Full-bleed flutter_map with tower markers, polyline path, timeline |
| **JWT Auth** | Secure login, bcrypt passwords, token auto-refresh, global logout |

## Tech Stack

- **Frontend**: Flutter (Dart) — Android + Windows
- **Backend**: Python FastAPI + Pandas
- **Database**: PostgreSQL 16 (via Docker)
- **Auth**: JWT (python-jose) + bcrypt (passlib)

## Quick Start

```bash
# 1. Start DB + API
docker-compose up --build

# 2. Run Flutter app
cd frontend
flutter pub get
flutter run -d windows        # Desktop
flutter run -d <device-id>    # Android
```

**Default login**: `admin` / `Admin@1234!`

> ⚠️ Change `JWT_SECRET_KEY` and admin credentials in `docker-compose.yml` before deploying.

## Project Structure

```
telecom-analyzer/
├── backend/          # FastAPI Python server
│   ├── app/
│   │   ├── models/   # SQLAlchemy ORM (CDR, SDR, TDR, User)
│   │   ├── schemas/  # Pydantic I/O schemas
│   │   ├── routers/  # API endpoints
│   │   └── services/ # Business logic (ingestion, search, graph, geo, auth)
│   └── sample_data/  # Sample CSV files for testing
├── frontend/         # Flutter cross-platform client
│   └── lib/
│       ├── core/     # Theme, routing, responsive layout
│       ├── data/     # Models + repositories
│       ├── screens/  # Feature screens
│       └── widgets/  # Shared UI components
└── docker-compose.yml
```

## API Endpoints

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/v1/auth/login` | ❌ | Obtain JWT token |
| POST | `/api/v1/auth/register` | Admin | Create new user |
| GET  | `/api/v1/auth/me` | ✅ | Current user profile |
| POST | `/api/v1/upload/{type}` | ✅ | CSV ingest (cdr/sdr/tdr) |
| GET  | `/api/v1/search` | ✅ | Phone / IMEI search |
| POST | `/api/v1/graph` | ✅ | Link analysis graph |
| GET  | `/api/v1/towers` | ✅ | Geo-map tower data |
