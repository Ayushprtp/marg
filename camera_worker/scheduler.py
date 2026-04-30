import asyncio
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_SERVICE_KEY
from challan import check_payment_deadlines
# from detector import SlotDetector # Delayed import

scheduler = AsyncIOScheduler()
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async def check_expired_bookings():
    pass # Implementation for expired bookings

async def load_and_poll_cameras():
    """Load all active cameras from Supabase, poll each every 30 seconds"""
    from detector import SlotDetector
    try:
        cameras = supabase.table('cameras')\
            .select('*, parking_lots(id)')\
            .eq('is_active', True)\
            .execute()
        
        for cam in cameras.data:
            detector = SlotDetector(cam)
            scheduler.add_job(
                detector.detect_and_report,
                'interval',
                seconds=30,
                id=f"cam_{cam['id']}",
                replace_existing=True
            )
    except Exception as e:
        print(f"Warning: Failed to load cameras from Supabase. Error: {e}")
        print("Please check your SUPABASE_URL and SUPABASE_SERVICE_KEY in .env")

# Also add booking expiry check job
scheduler.add_job(check_expired_bookings, 'interval', minutes=2)
scheduler.add_job(check_payment_deadlines, 'interval', hours=1)
