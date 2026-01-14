from app import create_app
from models import User, Customer, UserRole

app = create_app()
with app.app_context():
    workers = User.query.filter_by(role=UserRole.FIELD_AGENT, is_active=True).all()
    customers = Customer.query.filter_by(status='active').all()
    
    print(f"Total Workers: {len(workers)}")
    for w in workers:
        print(f"Worker {w.id} ({w.name}): Area='{w.area}'")
        
    print(f"\nTotal Active Customers: {len(customers)}")
    for c in customers:
        print(f"Customer {c.id} ({c.name}): Area='{c.area}', Worker='{c.assigned_worker_id}'")
