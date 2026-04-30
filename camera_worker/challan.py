from datetime import datetime, time, timedelta
import math
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_SERVICE_KEY

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async def check_payment_deadlines():
    """Check sessions where payment_deadline has passed"""
    overdue = supabase.table('parking_sessions')\
        .select('*')\
        .eq('payment_status', 'pending')\
        .lt('payment_deadline', datetime.utcnow().isoformat())\
        .execute()
    
    for session in overdue.data:
        await issue_challan(session)

async def issue_challan(session: dict):
    # Mock PDF generation
    challan_pdf = b'Mock PDF content'
    url = f"https://mock-storage.com/challans/{session['id']}.pdf"
    
    # Update session
    supabase.table('parking_sessions').update({
        'payment_status': 'challan_issued',
        'challan_issued': True,
        'challan_pdf_url': url,
    }).eq('id', session['id']).execute()
    
    # Push notification mock
    print(f"Issued challan for session {session['id']} - Amount: {session['amount_due']}")
