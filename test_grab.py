"""Quick test: grab a frame from the MJPEG stream, split into 4 slots, save each."""
import cv2, requests, numpy as np, os

STREAM = "https://surge-thermal-carmen-thrown.trycloudflare.com/stream"

print("Grabbing frame from:", STREAM)
resp = requests.get(STREAM, stream=True, timeout=30)
buf = b""
frame = None
for chunk in resp.iter_content(chunk_size=8192):
    buf += chunk
    start = buf.find(b"\xff\xd8")
    end = buf.find(b"\xff\xd9", start + 2 if start != -1 else 0)
    if start != -1 and end != -1 and end > start:
        jpg = buf[start : end + 2]
        frame = cv2.imdecode(np.frombuffer(jpg, np.uint8), cv2.IMREAD_COLOR)
        resp.close()
        break
    if len(buf) > 5_000_000:
        resp.close()
        break

if frame is None:
    print("ERROR: Could not grab frame!")
    exit(1)

h, w, _ = frame.shape
print(f"Frame size: {w}x{h}")

# Save full frame
cv2.imwrite("frame_full.jpg", frame)
print("Saved frame_full.jpg")

# Split into 4 slots
num_slots = 4
slot_w = w // num_slots
for i in range(num_slots):
    x1 = i * slot_w
    x2 = w if i == num_slots - 1 else (i + 1) * slot_w
    slot = frame[:, x1:x2]
    fname = f"frame_slot_{i+1}.jpg"
    cv2.imwrite(fname, slot)
    print(f"Saved {fname} ({x1}-{x2})")

print("Done! Check the slot images to verify division is correct.")
