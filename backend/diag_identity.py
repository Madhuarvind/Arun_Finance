from app import create_app
from extensions import db
from models import User

app = create_app()
with app.app_context():
    print("User Audit for JWT Identity Mismatch:")
    print("-" * 60)
    for u in User.query.all():
        identity_pin = u.name
        identity_admin = u.username
        
        # Check lookup logic from line.py
        found_as_pin = User.query.filter(
            (User.username == identity_pin) | (User.id == identity_pin) | (User.mobile_number == identity_pin)
        ).first()
        
        found_as_admin = User.query.filter(
            (User.username == identity_admin) | (User.id == identity_admin) | (User.mobile_number == identity_admin)
        ).first() if identity_admin else None

        print(f"ID: {u.id} | Name: '{u.name}' | Username: '{u.username}' | Role: {u.role}")
        print(f"  Login Identity (PIN): '{identity_pin}' -> Found in line.py lookup? {'YES' if found_as_pin else 'NO'}")
        if identity_admin:
            print(f"  Login Identity (Admin): '{identity_admin}' -> Found in line.py lookup? {'YES' if found_as_admin else 'NO'}")
        print("-" * 60)
