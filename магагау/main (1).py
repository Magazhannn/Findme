from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException, WebSocket
from pydantic import BaseModel
from typing import Optional, List
import json

# Internal service clients (implement separately as microservices)
# import ai_service_client
# import faiss_client
# import redis_client

app = FastAPI(
    title="FindMe AI Core",
    version="1.0",
    description="AI-powered missing person search platform"
)


# ──────────────────────────────────────────────
# Pydantic Models
# ──────────────────────────────────────────────

class Characteristics(BaseModel):
    gender: Optional[str] = None
    hair_color: Optional[str] = None
    hair_type: Optional[str] = None
    hair_length: Optional[str] = None
    height: Optional[str] = None
    body_type: Optional[str] = None
    skin_color: Optional[str] = None
    facial_hair: Optional[str] = None
    tattoo: Optional[bool] = None
    age_range: Optional[str] = None


class SearchRequest(BaseModel):
    characteristics: Characteristics
    clip_prompt: Optional[str] = None


# ──────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────

@app.get("/")
async def root():
    return {"message": "FindMe AI is running"}


@app.post("/api/v1/search/hybrid")
async def hybrid_search(
    image: Optional[UploadFile] = File(None),
    data: str = Form(...)
):
    """
    Hybrid search: face image + text prompt + structured characteristics.
    """
    try:
        search_params = SearchRequest.parse_raw(data)
        embedding = None

        # 1. Face image → AI microservice → embedding
        if image:
            image_bytes = await image.read()
            # ai_response = await ai_service_client.extract_face_features(image_bytes)
            # if not ai_response.is_live:
            #     raise HTTPException(status_code=400, detail="Spoofing detected.")
            # embedding = ai_response.embedding
            pass

        # 2. Text prompt → CLIP embedding
        clip_embedding = None
        if search_params.clip_prompt:
            # clip_embedding = await ai_service_client.get_clip_text_embedding(search_params.clip_prompt)
            pass

        # 3. Hybrid FAISS search
        # results = await faiss_client.search(
        #     face_vector=embedding,
        #     clip_vector=clip_embedding,
        #     filters=search_params.characteristics.dict(exclude_none=True)
        # )

        results = []  # placeholder

        return {"status": "success", "matches": results}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/search/face")
async def face_only_search(image: UploadFile = File(...)):
    """
    Search by face image only — extract embedding and query FAISS.
    """
    image_bytes = await image.read()
    # embedding = await ai_service_client.extract_face_features(image_bytes)
    # results = await faiss_client.search(face_vector=embedding.embedding)
    return {"status": "success", "matches": []}


@app.post("/api/v1/search/characteristics")
async def characteristics_search(chars: Characteristics):
    """
    Search by structured person attributes only.
    """
    filters = chars.dict(exclude_none=True)
    # results = await faiss_client.search(filters=filters)
    return {"status": "success", "filters_applied": filters, "matches": []}


@app.websocket("/ws/alerts/{user_id}")
async def websocket_alerts(websocket: WebSocket, user_id: str):
    """
    Real-time WebSocket alerts when a person is detected on camera.
    Subscribes to Redis Pub/Sub channel for the given user.
    """
    await websocket.accept()
    try:
        # pubsub = redis_client.pubsub()
        # await pubsub.subscribe(f"alerts:{user_id}")
        # async for message in pubsub.listen():
        #     if message["type"] == "message":
        #         await websocket.send_json(json.loads(message["data"]))
        while True:
            await websocket.receive_text()  # keep connection alive
    except Exception:
        await websocket.close()
