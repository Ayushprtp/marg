import cv2
import easyocr
import requests
import base64
import json
import numpy as np
import math
from datetime import datetime, time, timedelta
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_SERVICE_KEY, CONFIDENCE_THRESHOLD

reader = easyocr.Reader(['en'])
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

FLARE_API_KEY = "sk-8CKT2MRqsaaIAfRjOtfyG8fxsucnjVD4odIy4kZNSQMalHEh"
FLARE_API_URL = "https://api.flare-sh.tech/v1/chat/completions"
FLARE_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

class SlotDetector:
    def __init__(self, camera_config: dict):
        self.camera_id = camera_config['id']
        self.lot_id = camera_config['lot_id']
        self.stream_url = camera_config['stream_url']
        self.is_virtual = camera_config.get('is_virtual', False)
        self.camera_type = camera_config['camera_type']  # slot_cam or entry_cam
        self.covers_slots = camera_config.get('covers_slots', [])
        self.prev_states = {}  # slot_label -> bool (occupied)

    def get_frame(self) -> np.ndarray | None:
        """
        Handle different stream types:
        - RTSP: rtsp://...
        - Virtual/Webcam: integer index (0, 1, 2)
        - HTTP MJPEG: http://...
        - OBS Virtual Camera: typically index 0 or 1
        """
        if str(self.stream_url).isdigit():
            cap = cv2.VideoCapture(int(self.stream_url))
        else:
            cap = cv2.VideoCapture(self.stream_url)
        
        ret, frame = cap.read()
        cap.release()
        return frame if ret else None

    async def detect_and_report(self):
        frame = self.get_frame()
        if frame is None:
            print(f"[WARN] Could not read frame from camera {self.camera_id}")
            return

        snapshot_url = await self._upload_snapshot(frame)

        if self.camera_type == 'slot_cam':
            await self._process_slot_occupancy(frame, snapshot_url)
        else:
            await self._process_plate_detection(frame, snapshot_url)
            
    async def _upload_snapshot(self, frame) -> str:
        # Mock upload implementation
        return "https://mock-storage.com/snapshot.jpg"

    async def _process_slot_occupancy(self, frame, snapshot_url):
        # Encode image to base64
        _, buffer = cv2.imencode('.jpg', frame)
        img_base64 = base64.b64encode(buffer.tobytes()).decode('utf-8')
        
        prompt = "Does this image contain a parked vehicle in the parking spot? Reply with only YES or NO."
        
        payload = {
            "model": FLARE_MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_base64}"}}
                    ]
                }
            ],
            "max_tokens": 10
        }
        
        headers = {
            "Authorization": f"Bearer {FLARE_API_KEY}",
            "Content-Type": "application/json"
        }
        
        try:
            resp = requests.post(FLARE_API_URL, json=payload, headers=headers)
            resp_data = resp.json()
            answer = resp_data.get('choices', [{}])[0].get('message', {}).get('content', '').strip().upper()
            is_occupied = 'YES' in answer
        except Exception as e:
            print(f"[ERROR] Flare API error: {e}")
            is_occupied = False
            
        for slot_label in self.covers_slots:
            prev = self.prev_states.get(slot_label, None)
            
            if prev != is_occupied:  # STATE CHANGED
                self.prev_states[slot_label] = is_occupied
                
                event_type = 'vehicle_parked' if is_occupied else 'vehicle_unparked'
                
                # 1. Insert camera_event
                supabase.table('camera_events').insert({
                    'camera_id': self.camera_id,
                    'lot_id': self.lot_id,
                    'event_type': event_type,
                    'slot_label': slot_label,
                    'confidence': 1.0 if is_occupied else 0.0,
                    'snapshot_url': snapshot_url,
                    'processed': False,
                }).execute()
                
                # 2. Update slot status
                new_status = 'occupied' if is_occupied else 'free'
                supabase.table('parking_slots')\
                    .update({'status': new_status, 'last_updated': 'now()'})\
                    .eq('lot_id', self.lot_id)\
                    .eq('slot_label', slot_label)\
                    .execute()

    async def _process_plate_detection(self, frame, snapshot_url):
        h, w = frame.shape[:2]
        plate_region = frame[int(h*0.4):h, :]
        
        results = reader.readtext(plate_region)
        import re
        plate_pattern = re.compile(r'[A-Z]{2}[0-9]{2}[A-Z]{1,3}[0-9]{1,4}')
        
        for (bbox, text, conf) in results:
            text_clean = text.upper().replace(' ', '').replace('-', '')
            match = plate_pattern.search(text_clean)
            
            if match and conf > 0.5:
                plate = match.group()
                await self._handle_plate_detected(plate, conf, snapshot_url)
                break

    async def _handle_plate_detected(self, plate: str, confidence: float, snapshot_url: str):
        supabase.table('camera_events').insert({
            'camera_id': self.camera_id,
            'lot_id': self.lot_id,
            'event_type': 'plate_detected',
            'plate_text': plate,
            'confidence': confidence,
            'snapshot_url': snapshot_url,
        }).execute()
        
        vehicle = supabase.table('vehicles')\
            .select('id, user_id, plate_number, vehicle_type')\
            .eq('plate_number', plate)\
            .execute()
            
        if not vehicle.data:
            print(f"[INFO] Plate {plate} not registered in SmartPark")
            return
        
        if self.camera_type == 'entry_cam':
            await self._create_session_for_user(vehicle.data[0], plate, snapshot_url)
        elif self.camera_type == 'exit_cam':
            await self._close_session_for_user(vehicle.data[0], snapshot_url)

    async def _create_session_for_user(self, vehicle, plate, snapshot_url):
        existing = supabase.table('parking_sessions')\
            .select('id')\
            .eq('vehicle_id', vehicle['id'])\
            .is_('exited_at', 'null')\
            .execute()
        
        if existing.data:
            return
        
        session = supabase.table('parking_sessions').insert({
            'user_id': vehicle['user_id'],
            'slot_id': None,
            'lot_id': self.lot_id,
            'vehicle_id': vehicle['id'],
            'plate_detected': plate,
            'camera_entry_snapshot': snapshot_url,
            'entered_at': datetime.utcnow().isoformat(),
        }).execute()

    async def _close_session_for_user(self, vehicle, snapshot_url):
        session = supabase.table('parking_sessions')\
            .select('*')\
            .eq('vehicle_id', vehicle['id'])\
            .is_('exited_at', 'null')\
            .execute()
        
        if not session.data:
            return
            
        sess = session.data[0]
        entered_at = datetime.fromisoformat(sess['entered_at'])
        exited_at = datetime.utcnow()
        duration_mins = int((exited_at - entered_at).total_seconds() / 60)
        
        slot = supabase.table('parking_slots').select('*').eq('id', sess.get('slot_id')).execute()
        amount = _compute_bill(slot.data[0], duration_mins) if slot.data else 0
        payment_deadline = exited_at + timedelta(hours=48)
        
        supabase.table('parking_sessions').update({
            'exited_at': exited_at.isoformat(),
            'duration_minutes': duration_mins,
            'amount_due': amount,
            'payment_status': 'pending',
            'payment_deadline': payment_deadline.isoformat(),
            'camera_exit_snapshot': snapshot_url,
        }).eq('id', sess['id']).execute()

def _compute_bill(slot: dict, duration_mins: int) -> float:
    now = datetime.utcnow()
    is_peak = False
    if slot.get('peak_hours_start') and slot.get('peak_hours_end'):
        peak_start = time.fromisoformat(slot['peak_hours_start'])
        peak_end = time.fromisoformat(slot['peak_hours_end'])
        is_peak = peak_start <= now.time() <= peak_end
    
    rate = float(slot['peak_price_per_hour'] if is_peak and slot.get('peak_price_per_hour') else slot['price_per_hour'])
    hours = max(1, math.ceil(duration_mins / 60))
    if duration_mins <= 15:
        return 0.0
    return round(hours * rate, 2)
