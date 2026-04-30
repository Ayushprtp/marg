import os
import requests
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")

def sb_headers():
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

def delete_dummy():
    # Find user ID for Ayush Pratap
    print("Finding dummy bookings...")
    r = requests.get(f"{SUPABASE_URL}/rest/v1/bookings?select=*", headers=sb_headers())
    bookings = r.json()
    for b in bookings:
        print("Booking:", b)
        # We can delete booking linked to DB City Mall if lot name is DB City Mall,
        # but let's just delete all 'active' or 'arrived' bookings that are not Oriental Workshop
        
    r = requests.get(f"{SUPABASE_URL}/rest/v1/parking_sessions?select=*", headers=sb_headers())
    sessions = r.json()
    for s in sessions:
        print("Session:", s)

delete_dummy()
