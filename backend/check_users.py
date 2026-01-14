from app import create_app
from models import User

app = create_app()
with app.app_context():
    print(f"{'ID':<3} | {'Name':<20} | {'User':<10} | {'Role':<12}")
    print("-" * 50)
    for u in User.query.all():
        print(f"{u.id:<3} | {u.name:<20} | {u.username or '-':<10} | {u.role.value:<12}")
