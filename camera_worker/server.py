"""
MarG Camera Worker — Smart Parking Detection Server
Monitors MJPEG feeds, detects vehicle park/unpark via image differencing
+ Flare Vision API OCR, updates Supabase slots & sessions in real-time.

Multi-frame OCR consensus: When a vehicle is first detected, the system
captures 3-5 OCR readings across successive frames and picks the most
consistent plate number before committing to the database.
"""

import os, cv2, json, time, base64, logging, threading
import numpy as np
import requests
from collections import Counter
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
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "10"))
CHANGE_THRESH  = float(os.getenv("CHANGE_THRESH", "0.01"))  # 1% pixel change triggers analysis
OCR_CONSENSUS_ROUNDS = int(os.getenv("OCR_CONSENSUS_ROUNDS", "5"))  # Increased for better accuracy
OCR_CONSENSUS_DELAY  = float(os.getenv("OCR_CONSENSUS_DELAY", "2.0"))  # Faster polling during consensus

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

def sb_update_slot_status(lot_id, slot_label, occupied: bool):
    """Update the status of a parking slot in Supabase.
    occupied=True => status='occupied', else 'free'
    """
    status = 'occupied' if occupied else 'free'
    # Use PATCH to update the slot record matching lot_id and slot_label
    payload = {"status": status}
    # Supabase REST patch endpoint with filter
    url = f"{SUPABASE_URL}/rest/v1/parking_slots?lot_id=eq.{lot_id}&slot_label=eq.{slot_label}"
    r = requests.patch(url, headers=sb_headers(), json=payload, timeout=10)
    if r.status_code >= 400:
        log.error(f"Failed to update slot {slot_label} status to {status}: {r.status_code} {r.text}")
    else:
        log.info(f"Slot {slot_label} status set to {status}")
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

VISION_PROMPT = """Analyze this parking slot image.
1. Determine if a vehicle (car, bike, suv, truck) is present.
2. If present, extract the vehicle's license plate number accurately. Look specifically for Indian license plates (e.g., MP20SJ1641, MH12AB1234).
3. Identify the vehicle type.
4. Provide a confidence score for your detection.

CRITICAL: If a vehicle is present but the plate is partially obscured, try your best to read the visible characters. Normalize the plate format by removing spaces and special characters.

Respond ONLY with valid JSON (no markdown, no explanation, no backticks):
{"vehicle_present": true/false, "plate_number": "MP20SJ1641" or null, "vehicle_type": "car"/"bike"/"suv"/"truck"/null, "confidence": 0.0-1.0}"""

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


def normalize_plate(plate):
    """Normalize a plate string for comparison: uppercase, strip spaces/hyphens."""
    if not plate:
        return None
    return plate.replace(" ", "").replace("-", "").replace(".", "").upper().strip()


def consensus_plate(readings):
    """
    Given a list of plate readings (strings or None), return the best consensus plate.
    Uses frequency voting across normalized readings. If no clear winner, returns the
    most common non-None value.
    """
    cleaned = [normalize_plate(r) for r in readings if r is not None]
    if not cleaned:
        return None

    # Count occurrences
    counts = Counter(cleaned)
    best_plate, best_count = counts.most_common(1)[0]

    log.info(f"  OCR Consensus: {dict(counts)} → winner='{best_plate}' (seen {best_count}/{len(readings)} times)")
    return best_plate


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
        # Pending consensus tracker: slot_label -> {"readings": [...], "vehicle_types": [...], "confidences": [...]}
        self.pending_consensus = {}
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

    def _grab_slot_frame(self, slot_index, num_slots):
        """Grab a fresh frame from the stream and crop to the given slot."""
        frame, jpg = grab_frame(self.config["stream_url"])
        if frame is None:
            return None, None
        self.latest_frame_jpg = jpg
        height, width, _ = frame.shape
        slot_width = width // num_slots
        x_start = slot_index * slot_width
        x_end = width if slot_index == num_slots - 1 else (slot_index + 1) * slot_width
        slot_frame = frame[:, x_start:x_end]
        _, buffer = cv2.imencode('.jpg', slot_frame)
        return slot_frame, buffer.tobytes()

    def _run_consensus_ocr(self, slot_index, num_slots, slot_label):
        """
        Run multiple OCR reads on fresh frames for a slot, then vote on the best plate.
        This runs in-line (blocking) so that by the time we return, we have a consensus.
        """
        plate_readings = []
        vehicle_types = []
        confidences = []
        presence_votes = []

        log.info(f"[{self.config['name']}] Starting {OCR_CONSENSUS_ROUNDS}-round OCR consensus for {slot_label}...")

        for round_num in range(OCR_CONSENSUS_ROUNDS):
            # Grab a fresh frame for each round
            if round_num > 0:
                time.sleep(OCR_CONSENSUS_DELAY)

            slot_frame, slot_jpg = self._grab_slot_frame(slot_index, num_slots)
            if slot_jpg is None:
                log.warning(f"  Round {round_num+1}: frame grab failed, skipping")
                continue

            result = analyze_frame_with_vision(slot_jpg)
            if result is None:
                log.warning(f"  Round {round_num+1}: API returned None, skipping")
                continue

            vehicle_present = result.get("vehicle_present", False)
            plate = result.get("plate_number")
            vtype = result.get("vehicle_type")
            conf = result.get("confidence", 0.5)

            presence_votes.append(vehicle_present)
            plate_readings.append(plate)
            vehicle_types.append(vtype)
            confidences.append(conf)

            log.info(f"  Round {round_num+1}/{OCR_CONSENSUS_ROUNDS}: present={vehicle_present} plate={plate} type={vtype} conf={conf}")

        if not presence_votes:
            return None, None, None, None

        # Majority vote on presence
        presence_count = sum(1 for v in presence_votes if v)
        vehicle_present = presence_count > len(presence_votes) / 2

        # Consensus plate
        final_plate = consensus_plate(plate_readings) if vehicle_present else None

        # Most common vehicle type
        vtypes_clean = [v for v in vehicle_types if v is not None]
        final_vtype = Counter(vtypes_clean).most_common(1)[0][0] if vtypes_clean else None

        # Average confidence
        avg_conf = sum(confidences) / len(confidences) if confidences else 0.5

        log.info(f"[{self.config['name']}] Consensus result for {slot_label}: "
                 f"present={vehicle_present} plate={final_plate} type={final_vtype} conf={avg_conf:.2f}")

        return vehicle_present, final_plate, final_vtype, avg_conf

    def check(self):
        """Run one detection cycle for all slots."""
        frame, jpg = grab_frame(self.config["stream_url"])
        if frame is None:
            log.warning(f"[{self.config['name']}] Could not grab frame")
            return

        self.latest_frame_jpg = jpg
        now = time.time()
        force_check = (now - self.last_api_check) > 10  # every 10 sec
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
                continue

            if change > 0.1:  # Significant movement detected
                log.info(f"[{self.config['name']}] Slot {slot_label} Significant movement ({change:.3f}), waiting for stability...")
                continue

            log.info(f"[{self.config['name']}] Slot {slot_label} Change={change:.3f} (Stable) — running detection...")
            api_called = True

            # ── Quick single-read to determine presence ──
            _, buffer = cv2.imencode('.jpg', slot_frame)
            slot_jpg = buffer.tobytes()
            quick_result = analyze_frame_with_vision(slot_jpg)
            if quick_result is None:
                continue

            vehicle_now_quick = quick_result.get("vehicle_present", False)
            state = self.slots_state[slot_label]
            is_occupied = state["is_occupied"]

            # ── State transitions ──
            if vehicle_now_quick and not is_occupied:
                # → Vehicle MIGHT have just parked. Run multi-frame consensus for accurate plate.
                vehicle_confirmed, plate, vtype, confidence = self._run_consensus_ocr(i, num_slots, slot_label)

                if vehicle_confirmed:
                    state["is_occupied"] = True
                    state["plate"] = plate
                    self.add_event("vehicle_parked", plate, f"slot={slot_label} conf={confidence:.2f} type={vtype}")
                    resp = sb_rpc("process_camera_detection", {
                        "p_lot_id": self.lot_id,
                        "p_camera_id": self.config["camera_id"],
                        "p_slot_label": slot_label,
                        "p_plate_number": plate or "UNKNOWN",
                        "p_event_type": "vehicle_parked",
                        "p_confidence": confidence,
                    })
                    self.add_event("db_updated", plate, f"resp={json.dumps(resp)}")
                    # Update slot status to occupied in Supabase
                    sb_update_slot_status(self.lot_id, slot_label, True)
                else:
                    log.info(f"[{self.config['name']}] Consensus says NO vehicle in {slot_label} — false alarm")

            elif not vehicle_now_quick and is_occupied:
                # → Vehicle MIGHT have just left. Run consensus to confirm departure.
                vehicle_still, _, _, confidence = self._run_consensus_ocr(i, num_slots, slot_label)

                if not vehicle_still:
                    departed_plate = state["plate"] or "UNKNOWN"
                    state["is_occupied"] = False
                    state["plate"] = None
                    self.add_event("vehicle_unparked", departed_plate, f"slot={slot_label} conf={confidence:.2f}")
                    resp = sb_rpc("process_camera_detection", {
                        "p_lot_id": self.lot_id,
                        "p_camera_id": self.config["camera_id"],
                        "p_slot_label": slot_label,
                        "p_plate_number": departed_plate,
                        "p_event_type": "vehicle_unparked",
                        "p_confidence": confidence or 0.9,
                    })
                    self.add_event("db_updated", departed_plate, f"resp={json.dumps(resp)}")
                    # Update slot status to free in Supabase
                    sb_update_slot_status(self.lot_id, slot_label, False)
                else:
                    log.info(f"[{self.config['name']}] Consensus says vehicle STILL in {slot_label} — false alarm")

            elif vehicle_now_quick and is_occupied:
                # Vehicle still there. Optionally re-read plate if current plate is UNKNOWN.
                if state["plate"] is None or state["plate"] == "UNKNOWN":
                    plate_raw = quick_result.get("plate_number")
                    plate_clean = normalize_plate(plate_raw)
                    if plate_clean:
                        log.info(f"[{self.config['name']}] Updating unknown plate for {slot_label} → {plate_clean}")
                        state["plate"] = plate_clean
                else:
                    log.info(f"[{self.config['name']}] Slot {slot_label} No state change (still occupied, plate={state['plate']})")

            else:
                log.info(f"[{self.config['name']}] Slot {slot_label} No state change (still empty)")

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
        "ocr_consensus_rounds": OCR_CONSENSUS_ROUNDS,
    })


@app.route("/stream/<lot_id>")
def proxy_stream(lot_id):
    """Proxy the MJPEG stream from the camera feed for the Flutter app with YOLO-like overlays."""
    cam = CAMERAS.get(lot_id)
    if not cam:
        return jsonify({"error": "camera not found"}), 404

    mon = monitors.get(lot_id)

    def relay():
        cap = cv2.VideoCapture(cam["stream_url"])
        if not cap.isOpened():
            log.error(f"Cannot open stream {cam['stream_url']} for proxy")
            return
            
        slots = cam.get("slots", ["A1"])
        num_slots = len(slots)

        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                    
                height, width, _ = frame.shape
                slot_width = width // num_slots
                
                # Draw overlay for each slot based on current state
                if mon:
                    with mon.lock:
                        for i, slot_label in enumerate(slots):
                            x_start = i * slot_width
                            x_end = width if i == num_slots - 1 else (i + 1) * slot_width
                            
                            state = mon.slots_state.get(slot_label, {})
                            is_occupied = state.get("is_occupied", False)
                            plate = state.get("plate", "UNKNOWN")
                            
                            # Draw rectangle
                            color = (0, 0, 255) if is_occupied else (0, 255, 0)
                            cv2.rectangle(frame, (x_start, 0), (x_end, height), color, 4)
                            
                            # Draw semi-transparent background for text
                            overlay = frame.copy()
                            cv2.rectangle(overlay, (x_start, 0), (x_start + 250, 90), (0, 0, 0), -1)
                            cv2.addWeighted(overlay, 0.5, frame, 0.5, 0, frame)
                            
                            # Draw label
                            label_text = f"Slot: {slot_label}"
                            status_text = "OCCUPIED" if is_occupied else "VACANT"
                            
                            cv2.putText(frame, f"{label_text} ({status_text})", (x_start + 10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2, cv2.LINE_AA)
                            
                            if is_occupied and plate and plate != "UNKNOWN":
                                cv2.putText(frame, f"Plate: {plate}", (x_start + 10, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2, cv2.LINE_AA)
                            elif is_occupied:
                                cv2.putText(frame, f"Detecting...", (x_start + 10, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2, cv2.LINE_AA)
                
                # Encode and yield
                ret_encode, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
                if not ret_encode:
                    continue
                    
                frame_bytes = buffer.tobytes()
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
                       
                # Add a small sleep to prevent maxing out CPU if stream is faster than real-time (like a local video file)
                time.sleep(0.03) 
                
        except GeneratorExit:
            pass
        except Exception as e:
            log.warning(f"Stream relay error: {e}")
        finally:
            cap.release()

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
    log.info(f"  OCR Consensus: {OCR_CONSENSUS_ROUNDS} rounds, {OCR_CONSENSUS_DELAY}s delay")
    log.info("=" * 60)
    init()
    log.info(f"Server starting on http://localhost:8001")
    app.run(host="0.0.0.0", port=8001, threaded=True, debug=False)
