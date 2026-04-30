"""
MarG Camera Worker — Smart Parking Detection Server
Monitors MJPEG feeds, detects vehicle park/unpark via image differencing
+ Flare Vision API OCR, updates Supabase slots & sessions in real-time.
"""

import os, cv2, json, time, base64, logging, threading
import numpy as np
import requests
from datetime import datetime, timezone
from flask import Flask, Response, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

# ─── Logging ───
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("camera_worker")

# ─── Config ───
FLARE_API_URL  = "https://api.flare-sh.tech/v1/chat/completions"
FLARE_API_KEY  = os.getenv("FLARE_API_KEY", "")
FLARE_MODEL    = os.getenv("FLARE_MODEL", "meta-llama/llama-4-scout-17b-16e-instruct")
SUPABASE_URL   = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY   = os.getenv("SUPABASE_ANON_KEY", "")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "30"))
CHANGE_THRESH  = 0.03  # 3% pixel change triggers analysis

# ─── Camera Registry (loaded from DB on startup) ───
CAMERAS = {}  # lot_id -> {stream_url, camera_id, slots, name}

app = Flask(__name__)
CORS(app)


# ════════════════════════════════════════════════════════════════
#  Supabase Helpers
# ════════════════════════════════════════════════════════════════

def sb_headers():
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

def sb_get(path):
    r = requests.get(f"{SUPABASE_URL}/rest/v1/{path}", headers=sb_headers(), timeout=10)
    r.raise_for_status()
    return r.json()

def sb_rpc(fn_name, payload):
    """Call a Supabase RPC function."""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/{fn_name}",
        headers=sb_headers(), json=payload, timeout=15,
    )
    if r.status_code >= 400:
        log.error(f"RPC {fn_name} failed: {r.status_code} {r.text}")
    return r.json() if r.ok else {"error": r.text}

def load_cameras_from_db():
    """Load camera config from Supabase cameras + parking_lots tables."""
    global CAMERAS
    try:
        cams = sb_get("cameras?is_active=eq.true&select=id,lot_id,stream_url,camera_label,covers_slots,parking_lots(name)")
        for cam in cams:
            lot_id = cam["lot_id"]
            CAMERAS[lot_id] = {
                "name": cam.get("parking_lots", {}).get("name", "Unknown"),
                "stream_url": cam["stream_url"].rstrip("/") + "/stream",
                "camera_id": cam["id"],
                "slots": cam.get("covers_slots") or [],
            }
        log.info(f"Loaded {len(CAMERAS)} camera(s): {[v['name'] for v in CAMERAS.values()]}")
    except Exception as e:
        log.error(f"Failed to load cameras from DB: {e}")

    # Fallback if no cameras loaded
    if not CAMERAS:
        CAMERAS["fb3995b6-3471-4ee2-835b-20a836e598a4"] = {
            "name": "Oriental Workshop",
            "stream_url": "https://surge-thermal-carmen-thrown.trycloudflare.com/stream",
            "camera_id": "68013cbc-2bfb-44f0-8840-040c6730804d",
            "slots": ["OW-A1", "OW-A2", "OW-A3", "OW-A4"],
        }
        log.info("Using fallback camera config for Oriental Workshop")


# ════════════════════════════════════════════════════════════════
#  Frame Capture from MJPEG
# ════════════════════════════════════════════════════════════════

def grab_frame(stream_url):
    """Grab one JPEG frame from an MJPEG stream. Returns (cv2_frame, raw_jpg_bytes)."""
    try:
        resp = requests.get(stream_url, stream=True, timeout=15)
        buf = b""
        for chunk in resp.iter_content(chunk_size=4096):
            buf += chunk
            start = buf.find(b"\xff\xd8")
            end = buf.find(b"\xff\xd9", start + 2 if start != -1 else 0)
            if start != -1 and end != -1 and end > start:
                jpg = buf[start : end + 2]
                frame = cv2.imdecode(np.frombuffer(jpg, np.uint8), cv2.IMREAD_COLOR)
                resp.close()
                return frame, jpg
            if len(buf) > 2_000_000:  # safety cap
                break
        resp.close()
    except Exception as e:
        log.warning(f"Frame grab failed for {stream_url}: {e}")
    return None, None


def compute_change(prev, curr):
    """Compute % of pixels that changed between two frames."""
    if prev is None or curr is None:
        return 1.0  # treat as full change on first frame
    g1 = cv2.cvtColor(prev, cv2.COLOR_BGR2GRAY)
    g2 = cv2.cvtColor(curr, cv2.COLOR_BGR2GRAY)
    # Resize to same dimensions if needed
    if g1.shape != g2.shape:
        g2 = cv2.resize(g2, (g1.shape[1], g1.shape[0]))
    diff = cv2.absdiff(g1, g2)
    _, thresh = cv2.threshold(diff, 30, 255, cv2.THRESH_BINARY)
    return np.count_nonzero(thresh) / thresh.size


# ════════════════════════════════════════════════════════════════
#  Flare Vision API — Vehicle Detection + Plate OCR
# ════════════════════════════════════════════════════════════════

VISION_PROMPT = """Analyze this parking lot camera image carefully.
1. Is there a vehicle (car/bike/truck) parked in view?
2. If yes, read the license plate number exactly as shown.

Respond ONLY with valid JSON (no markdown, no explanation):
{"vehicle_present": true/false, "plate_number": "XXYYZZ1234" or null, "vehicle_type": "car"/"bike"/"truck"/null, "confidence": 0.0-1.0}"""

def analyze_frame_with_vision(jpg_bytes):
    """Send frame to Flare API for vehicle detection + plate OCR."""
    try:
        b64 = base64.b64encode(jpg_bytes).decode("utf-8")
        resp = requests.post(
            FLARE_API_URL,
            headers={"Authorization": f"Bearer {FLARE_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": FLARE_MODEL,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": VISION_PROMPT},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                        ],
                    }
                ],
                "max_tokens": 200,
                "temperature": 0.1,
            },
            timeout=60,
        )
        if resp.status_code != 200:
            log.error(f"Flare API error {resp.status_code}: {resp.text[:300]}")
            return None

        content = resp.json()["choices"][0]["message"]["content"].strip()
        # Extract JSON from potential markdown wrapping
        if "```" in content:
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
            content = content.strip()
        result = json.loads(content)
        log.info(f"Vision API result: {result}")
        return result
    except json.JSONDecodeError as e:
        log.error(f"Failed to parse Vision API response: {e} — raw: {content[:200]}")
    except Exception as e:
        log.error(f"Vision API call failed: {e}")
    return None


# ════════════════════════════════════════════════════════════════
#  Detection State Machine (per lot)
# ════════════════════════════════════════════════════════════════

class LotMonitor:
    def __init__(self, lot_id, config):
        self.lot_id = lot_id
        self.config = config
        self.prev_frames = {}
        self.latest_frame_jpg = None
        self.slots_state = {}
        for s in self.config.get("slots", ["A1"]):
            self.slots_state[s] = {"is_occupied": False, "plate": None}
            self.prev_frames[s] = None
        self.last_api_check = 0
        self.events = []  # recent events log
        self.lock = threading.Lock()

    def add_event(self, event_type, plate, detail=""):
        ts = datetime.now(timezone.utc).isoformat()
        evt = {"time": ts, "type": event_type, "plate": plate, "detail": detail}
        with self.lock:
            self.events.append(evt)
            if len(self.events) > 100:
                self.events = self.events[-50:]
        log.info(f"[{self.config['name']}] {event_type}: plate={plate} {detail}")

    def check(self):
        """Run one detection cycle for all slots."""
        frame, jpg = grab_frame(self.config["stream_url"])
        if frame is None:
            log.warning(f"[{self.config['name']}] Could not grab frame")
            return

        self.latest_frame_jpg = jpg
        now = time.time()
        force_check = (now - self.last_api_check) > 300  # every 5 min
        api_called = False

        slots = self.config.get("slots", ["A1"])
        num_slots = len(slots)
        height, width, _ = frame.shape
        slot_width = width // num_slots

        for i, slot_label in enumerate(slots):
            # Crop the frame for this specific slot
            x_start = i * slot_width
            x_end = width if i == num_slots - 1 else (i + 1) * slot_width
            slot_frame = frame[:, x_start:x_end]

            prev = self.prev_frames[slot_label]
            change = compute_change(prev, slot_frame)
            self.prev_frames[slot_label] = slot_frame.copy()

            if change < CHANGE_THRESH and not force_check:
                log.debug(f"[{self.config['name']}] Slot {slot_label} Change {change:.3f} < threshold, skipping API")
                continue

            log.info(f"[{self.config['name']}] Slot {slot_label} Change={change:.3f} — calling Vision API...")
            api_called = True

            # Encode slot_frame to jpg
            _, buffer = cv2.imencode('.jpg', slot_frame)
            slot_jpg = buffer.tobytes()

            result = analyze_frame_with_vision(slot_jpg)
            if result is None:
                continue

            vehicle_now = result.get("vehicle_present", False)
            plate = result.get("plate_number")
            confidence = result.get("confidence", 0.5)

            # Clean plate number
            if plate:
                plate = plate.replace(" ", "").replace("-", "").upper()

            state = self.slots_state[slot_label]
            is_occupied = state["is_occupied"]
            current_plate = state["plate"]

            # State transitions
            if vehicle_now and not is_occupied:
                # → Vehicle just PARKED
                state["is_occupied"] = True
                state["plate"] = plate
                self.add_event("vehicle_parked", plate, f"slot={slot_label} conf={confidence}")
                resp = sb_rpc("process_camera_detection", {
                    "p_lot_id": self.lot_id,
                    "p_camera_id": self.config["camera_id"],
                    "p_slot_label": slot_label,
                    "p_plate_number": plate or "UNKNOWN",
                    "p_event_type": "vehicle_parked",
                    "p_confidence": confidence,
                })
                self.add_event("db_updated", plate, f"resp={json.dumps(resp)}")

            elif not vehicle_now and is_occupied:
                # → Vehicle just UNPARKED
                departed_plate = current_plate or "UNKNOWN"
                state["is_occupied"] = False
                state["plate"] = None
                self.add_event("vehicle_unparked", departed_plate, f"slot={slot_label} conf={confidence}")
                resp = sb_rpc("process_camera_detection", {
                    "p_lot_id": self.lot_id,
                    "p_camera_id": self.config["camera_id"],
                    "p_slot_label": slot_label,
                    "p_plate_number": departed_plate,
                    "p_event_type": "vehicle_unparked",
                    "p_confidence": confidence,
                })
                self.add_event("db_updated", departed_plate, f"resp={json.dumps(resp)}")

            else:
                s = "occupied" if vehicle_now else "empty"
                log.info(f"[{self.config['name']}] Slot {slot_label} No state change (still {s})")

        if api_called:
            self.last_api_check = now


    def get_status(self):
        with self.lock:
            slots_res = {}
            for s, st in self.slots_state.items():
                slots_res[s] = {"is_occupied": st["is_occupied"], "plate": st["plate"]}
            return {
                "lot_id": self.lot_id,
                "name": self.config["name"],
                "slots": slots_res,
                "recent_events": self.events.copy()
            }


# Global monitors dict
monitors = {}  # lot_id -> LotMonitor


def detection_loop():
    """Background thread: runs detection on all cameras every CHECK_INTERVAL seconds."""
    log.info(f"Detection loop started (interval={CHECK_INTERVAL}s)")
    while True:
        for lot_id, mon in monitors.items():
            try:
                mon.check()
            except Exception as e:
                log.error(f"Detection error for {lot_id}: {e}", exc_info=True)
        time.sleep(CHECK_INTERVAL)


# ════════════════════════════════════════════════════════════════
#  Flask Routes
# ════════════════════════════════════════════════════════════════

@app.route("/")
def index():
    return jsonify({
        "service": "MarG Camera Worker",
        "cameras": {k: v["name"] for k, v in CAMERAS.items()},
        "check_interval": CHECK_INTERVAL,
    })


@app.route("/stream/<lot_id>")
def proxy_stream(lot_id):
    """Proxy the MJPEG stream from the camera feed for the Flutter app."""
    cam = CAMERAS.get(lot_id)
    if not cam:
        return jsonify({"error": "camera not found"}), 404

    def relay():
        try:
            resp = requests.get(cam["stream_url"], stream=True, timeout=30)
            for chunk in resp.iter_content(chunk_size=4096):
                yield chunk
        except GeneratorExit:
            pass
        except Exception as e:
            log.warning(f"Stream relay error: {e}")

    return Response(relay(), mimetype="multipart/x-mixed-replace; boundary=frame")


@app.route("/snapshot/<lot_id>")
def snapshot(lot_id):
    """Return the latest captured frame as JPEG."""
    mon = monitors.get(lot_id)
    if not mon or not mon.latest_frame_jpg:
        return jsonify({"error": "no frame available"}), 404
    return Response(mon.latest_frame_jpg, mimetype="image/jpeg")


@app.route("/status")
def all_status():
    """Return detection status for all monitored lots."""
    result = {}
    for lot_id, mon in monitors.items():
        result[lot_id] = mon.get_status()
    return jsonify(result)


@app.route("/status/<lot_id>")
def lot_status(lot_id):
    """Return detection status for a specific lot."""
    mon = monitors.get(lot_id)
    if not mon:
        return jsonify({"error": "lot not monitored"}), 404
    return jsonify(mon.get_status())


@app.route("/events/<lot_id>")
def lot_events(lot_id):
    """Return all detection events for a lot."""
    mon = monitors.get(lot_id)
    if not mon:
        return jsonify({"error": "lot not monitored"}), 404
    return jsonify({"lot_id": lot_id, "events": mon.events})


@app.route("/trigger/<lot_id>", methods=["POST"])
def manual_trigger(lot_id):
    """Manually trigger a detection check for testing."""
    mon = monitors.get(lot_id)
    if not mon:
        return jsonify({"error": "lot not monitored"}), 404
    threading.Thread(target=mon.check, daemon=True).start()
    return jsonify({"status": "check triggered", "lot_id": lot_id})


# ════════════════════════════════════════════════════════════════
#  Startup
# ════════════════════════════════════════════════════════════════

def init():
    load_cameras_from_db()
    for lot_id, config in CAMERAS.items():
        monitors[lot_id] = LotMonitor(lot_id, config)
    t = threading.Thread(target=detection_loop, daemon=True)
    t.start()


if __name__ == "__main__":
    log.info("=" * 60)
    log.info("  MarG Camera Worker — Smart Parking Detection")
    log.info("=" * 60)
    init()
    log.info(f"Server starting on http://localhost:8001")
    app.run(host="0.0.0.0", port=8001, threaded=True, debug=False)
