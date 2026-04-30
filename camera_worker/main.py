"""
SmartPark Camera Detection Worker
Supports:
- Real IP cameras via RTSP
- OBS Virtual Camera (appears as /dev/video0 or index 0 on Windows)
- HTTP MJPEG streams
- For testing: any webcam index

Run: uvicorn main:app --port 8001
"""
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from scheduler import load_and_poll_cameras, scheduler
import cv2

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler.start()
    await load_and_poll_cameras()
    yield

app = FastAPI(title="SmartPark Camera Worker", lifespan=lifespan)

@app.get("/health")
async def health_check():
    return {"status": "ok"}

def get_stream_url(camera_id: str):
    # Dummy function to fetch actual stream URL from DB by ID, returning 0 for testing
    return 0

@app.get("/cameras/{camera_id}/stream")
async def stream_camera(camera_id: str):
    """
    Streams camera as MJPEG — Flutter app shows this in a WebView or mjpeg widget
    For OBS Virtual Camera: stream_url will be "0" (device index)
    """
    def generate():
        cap = cv2.VideoCapture(get_stream_url(camera_id))
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
    
    return StreamingResponse(generate(), media_type='multipart/x-mixed-replace;boundary=frame')
