from app import create_app
from extensions import db
from models import User, UserRole, Collection
from flask_jwt_extended import create_access_token
import json

app = create_app()
with app.app_context():
    print("Final Verification of Fixes:")
    print("-" * 50)
    
    # 1. Test Auto-Accounting
    with app.test_client() as client:
        resp = client.get("/api/reports/auto-accounting")
        print(f"Auto-Accounting Status: {resp.status_code}")
        if resp.status_code == 200:
            data = json.loads(resp.data)
            print(f"Auto-Accounting Data: Total={data.get('total')}, Count={data.get('count')}")
        else:
            print(f"Auto-Accounting ERROR: {resp.data}")

    # 2. Test Daily Report (History tab)
    admin = User.query.filter_by(role=UserRole.ADMIN).first()
    if admin:
        token = create_access_token(identity=admin.username)
        headers = {"Authorization": f"Bearer {token}"}
        today = "2026-01-13"
        with app.test_client() as client:
            url = f"/api/reports/daily?start_date={today}T00:00:00&end_date={today}T23:59:59"
            resp = client.get(url, headers=headers)
            print(f"Daily Report (History) Status: {resp.status_code}")
            if resp.status_code == 200:
                data = json.loads(resp.data)
                print(f"Daily Report Count: {len(data.get('report', []))}")
            else:
                print(f"Daily Report ERROR: {resp.data}")
    else:
        print("No Admin user found to test Daily Report")

    # 3. Test Agent Collection History
    agent = User.query.filter_by(role=UserRole.FIELD_AGENT).first()
    if agent:
        # Test with Name identity which was the previous bug
        token = create_access_token(identity=agent.name)
        headers = {"Authorization": f"Bearer {token}"}
        with app.test_client() as client:
            resp = client.get("/api/collection/history", headers=headers)
            print(f"Agent Collection History Status: {resp.status_code}")
            if resp.status_code == 200:
                data = json.loads(resp.data)
                print(f"Agent History Count: {len(data)}")
            else:
                print(f"Agent History ERROR: {resp.data}")
    else:
        print("No Agent user found to test history")
