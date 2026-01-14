from app import create_app
from extensions import db
from models import User, UserRole

app = create_app()
with app.app_context():
    users = User.query.all()
    print("ID | Name | Username | Mobile | Role")
    print("-" * 50)
    for u in users:
        print(f"{u.id} | {u.name} | {u.username} | {u.mobile_number} | {u.role}")
