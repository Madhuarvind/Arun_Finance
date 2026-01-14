from app import create_app
from extensions import db
from models import User

app = create_app()
with app.app_context():
    print("Verification of JWT Identity Lookup Fix:")
    print("-" * 80)
    print(f"{'ID':<3} | {'Name':<20} | {'Username':<15} | {'Role':<15} | {'Found?'}")
    print("-" * 80)
    for u in User.query.all():
        name = u.name or ""
        username = u.username or ""
        role_val = u.role.value if u.role else "None"
        
        # Identity logic: Agents use name, others might use username or name
        identity = name if role_val == "field_agent" else (username or name)
        
        found = User.query.filter(
            (User.username == identity)
            | (User.id == str(identity))
            | (User.mobile_number == identity)
            | (User.name == identity)
        ).first()

        status = "YES" if found and found.id == u.id else "NO"
        print(f"{u.id:<3} | {name:<20} | {username:<15} | {role_val:<15} | {status}")
    print("-" * 80)
