import base64, requests, json, os

prompt = """Analyze this parking slot image. Is there a vehicle parked in this specific slot?
If YES, what is the license plate number?
- Indian plates often follow formats like "MP 04 SN 4072" or "MP 20 SJ 1641".
Respond ONLY with valid JSON (no markdown, no explanation):
{"vehicle_present": true/false, "plate_number": "MP04SN4072" or null, "vehicle_type": "car"/"bike"/"truck"/null, "confidence": 0.0-1.0}"""

with open(r'C:\Users\alokp\.gemini\antigravity\brain\0d6d2895-7ff8-49ae-aeed-7e25007d281e\media__1777532516957.jpg', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode('utf-8')

resp = requests.post(
    'https://api.flare-sh.tech/v1/chat/completions',
    headers={'Authorization': 'Bearer sk-9vghn6UtC07mQLuO866R3gmhLR1ubgZRCrWxAEHf89pE4XCl', 'Content-Type': 'application/json'},
    json={
        'model': 'qwen3-vl:30b',
        'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': prompt}, {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{b64}'}}]}],
        'max_tokens': 200,
        'temperature': 0.1
    }
)
with open('scratch.json', 'w') as f:
    json.dump(resp.json(), f)
