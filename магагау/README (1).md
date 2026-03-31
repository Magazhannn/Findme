# FindMe AI 🔍

AI-powered platform to find missing people in crowds using cameras, face recognition, and multimodal search.

---

## Stack

| Layer     | Tech                                              |
|-----------|---------------------------------------------------|
| Backend   | Python · FastAPI · Celery · Redis                 |
| AI        | InsightFace · DeepFace · CLIP · YOLOv8 · FAISS   |
| Streaming | OpenCV · GStreamer · WebSocket                    |
| Database  | MySQL 8.0+ (persistent) · FAISS (in-memory)       |
| Storage   | AWS S3                                            |
| Frontend  | React · Tailwind CSS · Framer Motion · Mapbox     |

---

## Project Structure

```
findme-ai/
├── backend/
│   ├── main.py              # FastAPI app — API Gateway
│   └── requirements.txt
├── database/
│   └── schema.sql           # MySQL 8.0+ DDL — all tables
├── frontend/
│   ├── tailwind.config.js   # Design tokens (Quiet Harbor theme)
│   └── src/
│       └── components/
│           └── HeroUploadSection.jsx
└── README.md
```

---

## Features

- **Face Recognition Search** — upload photo → extract embedding → search FAISS index
- **Characteristics Search** — gender, hair, height, clothes, accessories filters
- **CLIP Multimodal Search** — photo + text prompt ("find this person in red jacket")
- **Real-time Video** — RTSP/WebRTC stream ingestion + WebSocket alerts
- **Edge AI** — face extracted in browser, only embedding sent to backend
- **OSINT** — scrape VK, Instagram, LinkedIn and link to detected faces
- **Geo Tracking** — lat/lng per detection, movement timeline
- **Heatmaps** — aggregated sighting visualization on map
- **Liveness Detection** — anti-spoofing (printed photo / screen replay)
- **Emotion Detection** — fear, aggression, panic, running

---

## Microservices Architecture

```
                  ┌─────────────────┐
  User/Client ──► │   API Gateway   │ (FastAPI)
                  └────────┬────────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
   │ AI Service  │  │FAISS Search │  │Stream Processor│
   │ InsightFace │  │  (in RAM)   │  │ OpenCV/GStream │
   │ CLIP/YOLO   │  └─────────────┘  └──────────────┘
   └─────────────┘
          │
   ┌──────┴──────┐
   ▼             ▼
Redis Queue   MySQL DB
 (Celery)     (persist)
```

---

## Database Tables

| Table                    | Purpose                            |
|--------------------------|------------------------------------|
| `users`                  | Platform accounts                  |
| `persons`                | Missing/tracked person entity      |
| `searches`               | Search request log                 |
| `face_embeddings`        | BLOB float32 vectors per face      |
| `characteristics`        | Structured person attributes       |
| `clothing_and_accessories` | JSON clothing/accessory data     |
| `camera_streams`         | RTSP camera registry               |
| `detections`             | Face spotted on camera (with GPS)  |
| `search_results`         | Matched embeddings per search      |
| `external_profiles`      | OSINT social media profiles        |
| `alerts`                 | Real-time notifications            |
| `heatmap_points`         | Aggregated sighting coords         |

---

## Setup

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### Database
```bash
mysql -u root -p < database/schema.sql
```

### Frontend
```bash
cd frontend
npm install
npm start
```

---

## Design Philosophy: "Quiet Harbor"

The UI uses **Organic Minimalism + Biophilic Design** to reduce user anxiety during emotionally stressful searches:

- **Colors:** Warm sand beige background, sage green primary, dusty rose accents
- **Shapes:** Large border-radius (rounded-3xl), no sharp edges
- **Animations:** Slow, organic ease-in-out, water-ripple effects
- **Typography:** Inter / Open Sans — no uppercase, soft headings

---

## API Endpoints

| Method | Endpoint                        | Description                  |
|--------|---------------------------------|------------------------------|
| POST   | `/api/v1/search/hybrid`         | Face + characteristics + CLIP |
| POST   | `/api/v1/search/face`           | Face image only               |
| POST   | `/api/v1/search/characteristics`| Attributes only               |
| WS     | `/ws/alerts/{user_id}`          | Real-time detection alerts    |
