from app import create_app
from extensions import db
from models import Line, User, UserRole

app = create_app()
with app.app_context():
    lines = Line.query.all()
    print(f"Total lines found: {len(lines)}")
    for l in lines:
        print(f"ID: {l.id}, Name: {l.name}, Area: {l.area}, Agent: {l.agent_id}")
    
    users = User.query.all()
    print("\nUsers Info:")
    for u in users:
        print(f"ID: {u.id}, Name: {u.name}, Username: {u.username}, Role: {u.role}")

    admins = User.query.filter_by(role=UserRole.ADMIN).all()
    print(f"\nAdmins: {[a.username for a in admins]}")
