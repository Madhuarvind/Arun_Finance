from app import app
from models import db, Line, LineCustomer, Customer

with app.app_context():
    line = Line.query.filter_by(name="Daily line Evening").first()
    if not line:
        print("Line 'Daily line Evening' not found.")
    else:
        print(f"Line ID: {line.id}")
        mappings = LineCustomer.query.filter_by(line_id=line.id).all()
        print(f"Found {len(mappings)} mappings.")
        for m in mappings:
            print(f" - Customer ID: {m.customer_id}, Name: {m.customer.name}, Order: {m.sequence_order}")
