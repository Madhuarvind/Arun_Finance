import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from app import create_app
from models import db, User, Customer, Line, LineCustomer, Collection, UserRole
from datetime import datetime

app = create_app()

with app.app_context():
    print("--- DB LOGIC VERIFICATION ---")
    
    # 1. Find a Field Agent
    agent = User.query.filter_by(role=UserRole.FIELD_AGENT).first()
    if not agent:
        print("No field agent found. Creation might be needed for real test.")
    else:
        print(f"Testing for Agent: {agent.name} (ID: {agent.id})")
        
        # 2. Test Customer List query logic
        from sqlalchemy import or_
        query = Customer.query.distinct().outerjoin(
            LineCustomer, Customer.id == LineCustomer.customer_id
        ).outerjoin(
            Line, LineCustomer.line_id == Line.id
        ).filter(
            or_(Customer.assigned_worker_id == agent.id, Line.agent_id == agent.id)
        )
        
        customers = query.all()
        print(f"Total customers visible to agent: {len(customers)}")
        for c in customers:
             print(f" - {c.name} (ID: {c.id})")

        # 3. Test Collection Stats logic
        today = datetime.utcnow().date()
        total_collected = (
            db.session.query(db.func.sum(Collection.amount))
            .filter(
                Collection.agent_id == agent.id,
                Collection.status.in_(["approved", "pending", "flagged"])
            )
            .scalar()
            or 0
        )
        print(f"Total collected today (incl. pending/flagged): {total_collected}")

print("--- VERIFICATION DONE ---")
