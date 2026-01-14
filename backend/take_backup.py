import json
from app import create_app
from extensions import db
from models import User, Customer, Loan, EMISchedule, Collection, Line, LoanAuditLog
import os

app = create_app()
backup_dir = "db_backup"
if not os.path.exists(backup_dir):
    os.makedirs(backup_dir)

def dump_table(model, filename):
    data = []
    items = model.query.all()
    for item in items:
        # Convert model instance to dict
        item_dict = {}
        for column in item.__table__.columns:
            val = getattr(item, column.name)
            if hasattr(val, 'value'): # Handle Enums
                val = val.value
            elif hasattr(val, 'isoformat'):
                val = val.isoformat()
            item_dict[column.name] = val
        data.append(item_dict)
    
    with open(os.path.join(backup_dir, filename), 'w') as f:
        json.dump(data, f, indent=4)
    print(f"Backed up {len(data)} rows from {model.__tablename__}")

with app.app_context():
    dump_table(User, "users.json")
    dump_table(Customer, "customers.json")
    dump_table(Loan, "loans.json")
    dump_table(EMISchedule, "emi_schedule.json")
    dump_table(Collection, "collections.json")
    dump_table(Line, "lines.json")
    dump_table(LoanAuditLog, "loan_audit_logs.json")
    print("\nBackup completed in 'db_backup' folder.")
