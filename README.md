# SmartPark — Full-Stack Smart Parking System

**SmartPark** is a complete solution for parking lot management and user bookings.

## Stack
- Frontend: Flutter (iOS + Android)
- Backend/DB: Supabase (Auth + Postgres + Realtime + Storage)
- Camera Worker: Python FastAPI microservice
- Maps: Google Maps Flutter SDK

## Project Structure
```
smartpark/
├── lib/                          # Flutter app
├── camera_worker/                # Python FastAPI service
├── supabase/                     # migrations + seed
└── README.md
```

## Features
1. **User Authentication & Profiles:** Roles (client, operator, root)
2. **Vehicle Management:** Clients can register and verify vehicles (via external API).
3. **Map & Discovery:** See active parking lots, view slots.
4. **Pre-Booking:** Pre-book slots with grace period.
5. **Operator Dashboard:** Add lots, slots, assign cameras.
6. **Smart Camera Detection:** Python backend uses YOLO to detect occupancy, and EasyOCR for License Plate Recognition.
7. **Automated Billing:** Detect entry and exit, generate bills, issue challans for unpaid parking.

## Setup
### 1. Supabase
Initialize Supabase and push migrations from `supabase/migrations/`.

### 2. Camera Worker
```bash
cd camera_worker
pip install -r requirements.txt
uvicorn main:app --port 8001
```

### 3. Flutter App
```bash
flutter pub get
flutter run
```

## Environment Setup
Create a `.env` in the root of the Flutter app with:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
GOOGLE_MAPS_API_KEY=your_maps_key
VEHICLE_API_BASE=https://abs-weblogs-gas-dude.trycloudflare.com
CAMERA_WORKER_URL=http://localhost:8001
RAZORPAY_KEY_ID=your_razorpay_key
```
Create `.env` in `camera_worker` with:
```
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_service_role_key
POLL_INTERVAL=30
CONFIDENCE_THRESHOLD=0.70
```
