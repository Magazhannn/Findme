# АРХИТЕКТУРА — FindMe AI

## Общая архитектура

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      FindMe AI — три точки входа                         │
├─────────────────┬────────────────────────┬───────────────────────────────┤
│  Web UI (React) │  REST API (FastAPI)     │  WebSocket (Real-time)        │
│  :3000          │  main.py :8000          │  /ws/alerts/{user_id}         │
└────────┬────────┴──────────┬─────────────┴──────────────┬────────────────┘
         │                  │                             │
         │          ┌───────▼──────────┐        ┌────────▼───────────┐
         │          │  API Gateway     │        │  Stream Processor  │
         └──────────►  /api/v1/search  │        │  OpenCV/GStreamer   │
                    │  hybrid_search() │        │  RTSP/WebRTC input │
                    └───────┬──────────┘        └────────┬───────────┘
                            │                            │
             ┌──────────────▼────────────────────────────▼──────────┐
             │                  AI Pipeline Core                      │
             │                                                        │
             │  1. Liveness Detection  (анти-спуфинг)                │
             │  2. Face Detection      (YOLOv8)                      │
             │  3. Embedding Extraction (InsightFace / DeepFace)     │
             │  4. CLIP Multimodal     (текст + фото → вектор)       │
             │  5. FAISS Search        (косинусное сходство, in-RAM) │
             │  6. Characteristics Filter (MySQL structured query)   │
             │  7. Result Ranking + WebSocket Alert                  │
             └──────┬──────────────────────────────┬─────────────────┘
                    │                              │
          ┌─────────▼──────────┐        ┌──────────▼──────────┐
          │   FAISS Index      │        │   MySQL 8.0+         │
          │   (float32, RAM)   │        │   findme_db          │
          │   rebuild on boot  │        │   (persistent)       │
          └────────────────────┘        └─────────────────────┘
                    │                              │
          ┌─────────▼──────────┐        ┌──────────▼──────────┐
          │   Redis + Celery   │        │   AWS S3             │
          │   (async workers)  │        │   (image storage)    │
          │   OSINT / Age Prog │        │                      │
          └────────────────────┘        └─────────────────────┘
```

---

## Три режима работы

| Режим | Точка входа | Порт | Запуск |
|-------|-------------|------|--------|
| **Web UI** | `frontend/` (React) | 3000 | `npm start` |
| **REST API** | `backend/main.py` (FastAPI) | 8000 | `uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000` |
| **Real-time** | `/ws/alerts/{user_id}` (WebSocket) | 8000 | автоматически при запуске FastAPI |

- **React UI** общается с бэкендом через REST и WebSocket
- **FastAPI** обрабатывает все запросы и раздаёт алерты через Redis Pub/Sub
- **Celery Workers** выполняют тяжёлые фоновые задачи (OSINT, age progression)

---

## AI Pipeline

### Автовыбор режима поиска

- Загружено **фото** → Face Embedding Search (InsightFace → FAISS)
- Загружено **фото + текст** → CLIP Multimodal Search (текст + изображение → объединённый вектор)
- Только **характеристики** → Structured Filter Search (MySQL ENUM-поля + индексы)
- **Все три** → Hybrid Search (взвешенное объединение результатов)

### Шаги pipeline

| # | Этап | Что делает | Ключевые параметры |
|---|------|------------|-------------------|
| 1 | **Liveness Detection** | Проверка: живой человек или фото/экран | анализ микротекстур, глубины |
| 2 | **Face Detection** | Поиск лиц на изображении/кадре | YOLOv8, confidence > 0.6 |
| 3 | **Embedding Extraction** | Лицо → float32-вектор | InsightFace ArcFace, 512 dim |
| 4 | **CLIP Encoding** | Текст + фото → общий вектор | openai/clip-vit-base-patch32 |
| 5 | **FAISS Search** | Косинусное сходство по индексу | top_k: 10, threshold: 0.6 |
| 6 | **Characteristics Filter** | Фильтрация по атрибутам (пол, рост, одежда) | MySQL ENUM + JSON |
| 7 | **Alert Dispatch** | Совпадение → Redis Pub/Sub → WebSocket | latency < 200ms |

### Структура эмбеддинга (face_embeddings)

```json
{
  "id": "uuid-v4",
  "person_id": "uuid-v4",
  "embedding": "<BLOB: float32[512]>",
  "source_type": "uploaded | cctv | scraped_vk | scraped_ig",
  "metadata": {
    "model": "arcface",
    "confidence": 0.97,
    "original_filename": "photo.jpg"
  },
  "created_at": "2025-01-01T00:00:00Z"
}
```

### Структура результата поиска

```json
{
  "method": "hybrid | face_only | clip | characteristics",
  "search_id": "uuid-v4",
  "total_matches": 3,
  "matches": [{
    "person_id": "uuid-v4",
    "similarity_score": 0.94,
    "last_seen": {
      "camera_id": "uuid-v4",
      "location": "ул. Абая, 12, Алматы",
      "lat": 43.238949,
      "lng": 76.889709,
      "timestamp": "2025-01-01T14:32:00Z"
    },
    "characteristics": {
      "gender": "male",
      "age_range": "adult",
      "hair_color": "black"
    },
    "external_profiles": [
      { "platform": "VK", "username": "ivan_ivanov", "url": "..." }
    ]
  }],
  "summary": "Найдено 3 совпадения. Последнее появление: 14:32, ул. Абая."
}
```

---

## Модули и файлы

### `backend/main.py` — API Gateway (FastAPI)

Принимает все входящие запросы, управляет JWT-авторизацией, маршрутизирует в сервисы.

**Эндпоинты:**

| Метод | Путь | Описание |
|-------|------|----------|
| `GET`  | `/api/v1/health` | Статус всех сервисов |
| `POST` | `/api/v1/search/hybrid` | Гибридный поиск (фото + текст + атрибуты) |
| `POST` | `/api/v1/search/face` | Поиск только по фото |
| `POST` | `/api/v1/search/characteristics` | Поиск по атрибутам |
| `POST` | `/api/v1/persons` | Создать карточку разыскиваемого |
| `GET`  | `/api/v1/persons/{id}/timeline` | Маршрут передвижения |
| `GET`  | `/api/v1/persons/{id}/heatmap` | Тепловая карта появлений |
| `POST` | `/api/v1/cameras` | Зарегистрировать RTSP-камеру |
| `WS`   | `/ws/alerts/{user_id}` | Real-time уведомления |

Swagger UI: `http://localhost:8000/docs`

---

### `backend/services/` — Микросервисный слой

| Файл | Назначение |
|------|------------|
| `ai_service.py` | Оркестрация AI: liveness → detect → embed → CLIP |
| `faiss_service.py` | Singleton FAISS-индекс, загрузка из MySQL при старте, поиск top-K |
| `stream_service.py` | Захват RTSP/WebRTC потоков, нарезка кадров, отправка в очередь |
| `osint_service.py` | Celery-задачи: парсинг VK, Instagram, LinkedIn → привязка к person_id |
| `age_progression.py` | Celery-задача: GAN/Diffusion генерация aged face → повторный поиск |
| `alert_service.py` | Redis Pub/Sub: публикация алертов → WebSocket раздача |
| `geo_service.py` | Сохранение lat/lng детекций, построение timeline и heatmap |

---

### `backend/core/` — Ядро системы

| Файл | Назначение |
|------|------------|
| `config.py` | `Settings(BaseSettings)` — загрузка из `.env` |
| `database.py` | SQLAlchemy engine + session factory (MySQL) |
| `models.py` | ORM-модели всех таблиц |
| `schemas.py` | Pydantic-модели: `SearchRequest`, `MatchResult`, `PersonCreate` и др. |
| `security.py` | JWT токены, хэширование паролей (passlib/bcrypt) |

---

### `frontend/src/` — React UI ("Quiet Harbor")

| Файл / Папка | Назначение |
|--------------|------------|
| `components/HeroUploadSection.jsx` | Drag & drop загрузка фото, water-ripple анимация |
| `components/SearchPanel.jsx` | Текстовый промпт + характеристики + фильтры |
| `components/ResultsGrid.jsx` | Карточки найденных людей с fade-in + blur reveal |
| `components/MapSection.jsx` | Mapbox: тепловая карта + маршрут передвижения |
| `components/LiveCamera.jsx` | WebRTC захват камеры + real-time детекция |
| `components/AlertBadge.jsx` | WebSocket уведомления в реальном времени |
| `hooks/useWebSocket.js` | Хук подключения к `/ws/alerts/{user_id}` |
| `hooks/useSearch.js` | Хук отправки поисковых запросов на API |
| `tailwind.config.js` | Дизайн-токены (цвета, шрифты, тени, радиусы) |

---

## Граф зависимостей

```
┌─────────────────────────────────────────────────────────────────────┐
│                        frontend/ (React)                            │
│                                                                     │
│  App.jsx → SearchPanel → HeroUploadSection                         │
│     │           │              │                                   │
│     │      useSearch.js   useWebSocket.js                          │
│     │           │              │                                   │
│     └───────────▼──────────────▼────────────────────────────────── │
│                     HTTP / WebSocket                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│                      backend/ (FastAPI)                              │
│                                                                      │
│  main.py → routes → ai_service ──┬─→ faiss_service                 │
│     │          │                  └─→ stream_service                │
│     │     schemas.py                                                │
│     │          │        celery workers:                             │
│  config.py     │        osint_service                               │
│  security.py   │        age_progression                             │
│                │                  │                                 │
│           database.py ◄───────────┘                                │
│           models.py                                                 │
└─────────────────────────────────────────────────────────────────────┘
                    │                     │
          ┌─────────▼──────┐    ┌─────────▼──────┐
          │  MySQL 8.0+    │    │  Redis          │
          │  findme_db     │    │  (queue/pubsub) │
          └────────────────┘    └────────────────┘
                    │
          ┌─────────▼──────┐
          │  FAISS (RAM)   │  ← восстанавливается из MySQL при старте
          │  AWS S3        │  ← хранение оригинальных фото
          └────────────────┘
```

---

## База данных — таблицы

| Таблица | Назначение |
|---------|------------|
| `users` | Аккаунты пользователей платформы |
| `persons` | Карточка разыскиваемого человека |
| `searches` | Лог всех поисковых запросов |
| `face_embeddings` | BLOB float32-векторы лиц (512 dim, ArcFace) |
| `characteristics` | Структурированные атрибуты: пол, рост, волосы, кожа |
| `clothing_and_accessories` | JSON: одежда, очки, сумка, часы, наушники |
| `camera_streams` | Реестр RTSP-камер с GPS-координатами |
| `detections` | История: кто, где, когда замечен + эмоция |
| `search_results` | Матчинг: search_id → face_embedding_id + score |
| `external_profiles` | OSINT: профили VK / Instagram / LinkedIn |
| `alerts` | Уведомления: detection_id → user_id |
| `heatmap_points` | Агрегированные точки появлений для карты |

---

## Конфигурация (.env)

```env
# Backend
HOST=0.0.0.0
PORT=8000
SECRET_KEY=your-secret-key

# Database
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=password
MYSQL_DB=findme_db

# AI Models
FACE_MODEL=insightface         # arcface, 512 dim
CLIP_MODEL=openai/clip-vit-base-patch32
YOLO_MODEL=yolov8n.pt

# FAISS
FAISS_INDEX_PATH=./data/faiss.index
FAISS_TOP_K=10
SIMILARITY_THRESHOLD=0.6

# Redis / Celery
REDIS_URL=redis://localhost:6379/0

# Storage
S3_BUCKET=findme-photos
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...

# Mapbox
MAPBOX_TOKEN=pk.eyJ1...
```

---

## Классификация детекций

**Типы поиска:** `face_only` (только фото), `clip_multimodal` (фото + текст), `characteristics` (атрибуты), `hybrid` (всё вместе)

**Эмоции:** `neutral`, `fear` (страх), `aggression` (агрессия), `panic` (паника), `running` (бег)

**Статус персоны:** `missing` (в розыске), `found` (найден), `tracking` (отслеживается)

**Критичность алерта:** `HIGH` (точное совпадение ≥ 0.9), `MEDIUM` (0.7–0.9), `LOW` (0.6–0.7)

---

## Технологический стек

| Компонент | Технология | Версия |
|-----------|-----------|--------|
| Backend API | FastAPI + Uvicorn | 0.111.0 / 0.29.0 |
| Frontend | React + Tailwind CSS | 18.x / 3.x |
| Анимации | Framer Motion | 11.x |
| Карта | Mapbox GL JS | 3.x |
| Face Recognition | InsightFace (ArcFace) | 0.7.3 |
| Face Analysis | DeepFace | 0.0.93 |
| Multimodal AI | CLIP (OpenAI) | via transformers |
| Object Detection | YOLOv8 | ultralytics 8.x |
| Vector Search | FAISS (Facebook) | faiss-cpu 1.8.0 |
| Deep Learning | PyTorch | 2.3.0 |
| ML Framework | HuggingFace Transformers | 4.41.0 |
| Async Queue | Celery + Redis | 5.4.0 / 5.0.4 |
| Database | MySQL 8.0+ (InnoDB, utf8mb4) | 8.0 |
| File Storage | AWS S3 + boto3 | 1.34.0 |
| Real-time | WebSocket (FastAPI native) | — |
| Video Capture | OpenCV + GStreamer | 4.9.0 |
| Auth | JWT + passlib/bcrypt | python-jose 3.3.0 |
| Data Validation | Pydantic + pydantic-settings | 2.7.1 |
| ORM | SQLAlchemy | 2.0.30 |
| HTTP Client | httpx | 0.27.0 |
