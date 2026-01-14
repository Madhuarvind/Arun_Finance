from app import create_app
from extensions import db
from models import Collection, Loan
from datetime import datetime, timedelta

app = create_app()
with app.app_context():
    print("Collection Audit:")
    print("-" * 100)
    print(f"{'ID':<3} | {'Loan ID':<7} | {'Amount':<10} | {'Status':<10} | {'Created At':<25} | {'Payment Mode'}")
    print("-" * 100)
    
    collections = Collection.query.all()
    for c in collections:
        print(f"{c.id:<3} | {c.loan_id:<7} | {c.amount:<10} | {c.status:<10} | {c.created_at} | {c.payment_mode}")
    
    print("\nRecent Approved Collections (Today):")
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = datetime.utcnow().replace(hour=23, minute=59, second=59, microsecond=999999)
    
    recent_approved = Collection.query.filter(
        Collection.status == 'approved',
        Collection.created_at >= today_start,
        Collection.created_at <= today_end
    ).all()
    
    print(f"Total Approved Today: {len(recent_approved)}")
    for r in recent_approved:
        print(f"ID: {r.id}, Amount: {r.amount}, Time: {r.created_at}")
    
    print("\nTesting get_auto_accounting filtering logic:")
    # Replicating reports.py logic
    morning_start = today_start.replace(hour=4) # 4 AM UTC
    morning_end = today_start.replace(hour=10) # 10 AM UTC
    evening_start = today_start.replace(hour=11) # 11 AM UTC
    evening_end = today_start.replace(hour=16) # 4 PM UTC
    
    print(f"Morning Range: {morning_start} to {morning_end}")
    print(f"Evening Range: {evening_start} to {evening_end}")
    
    for r in recent_approved:
        is_morning = morning_start <= r.created_at <= morning_end
        is_evening = evening_start <= r.created_at <= evening_end
        print(f"ID {r.id}: Morning? {is_morning}, Evening? {is_evening}")
