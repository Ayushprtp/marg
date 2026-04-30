# Testing with OBS Virtual Camera

## Setup
1. Install OBS Studio on your laptop
2. In OBS: Start Virtual Camera (Tools > Virtual Camera > Start)
3. OBS creates a virtual device: on Windows = "OBS Virtual Camera", on Linux = /dev/video2

## Add Test Camera in Operator Dashboard
- stream_url: "0" (or "1" or "2" — try each until OBS feed appears)
- camera_type: "slot_cam" OR "entry_cam" 
- is_virtual: true

## Test Scenarios
- **Slot Cam Test**: Put any object (your hand, phone) in front of webcam → detection fires
- **LPR Test**: Hold a printout or phone screen showing "DL1CAB1234" in front of webcam
  → OCR will try to read it → if it reads a valid plate format → session created
- **MJPEG Stream Test**: Open http://localhost:8001/cameras/{id}/stream in browser
  → Should show live feed
