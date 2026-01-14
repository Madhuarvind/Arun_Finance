from app import create_app
from extensions import db
from sqlalchemy import text
import bcrypt

app = create_app()

def hash_pass(password):
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

with app.app_context():
    print("Resetting database (forcing)...")
    
    # Disable foreign key checks
    db.session.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
    
    tables = [
        "collections", "emi_schedule", "loan_audit_logs", "loans", 
        "lines", "customers", "devices", "qr_codes", 
        "face_embeddings", "users", "loan_documents", "passbook_tokens"
    ]
    
    for table in tables:
        db.session.execute(text(f"TRUNCATE TABLE `{table}`;"))
        print(f"Truncated {table}")
    
    db.session.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
    db.session.commit()
    print("Database cleared.")

    from models import User, UserRole
    print("Creating live test users...")
    
    # 1. Admin: Arun
    admin_arun = User(
        name="Arun",
        username="Arun",
        password_hash=hash_pass("Arun@123"),
        mobile_number="9000000001",
        role=UserRole.ADMIN,
        is_first_login=False
    )
    db.session.add(admin_arun)
    
    # 2. Worker: Madhu (1111)
    worker_madhu = User(
        name="Madhu",
        pin_hash=hash_pass("1111"),
        mobile_number="9000000002",
        role=UserRole.FIELD_AGENT,
        is_first_login=False
    )
    db.session.add(worker_madhu)
    
    # 3. Worker: kaliselvan (1234)
    worker_kaliselvan = User(
        name="kaliselvan",
        pin_hash=hash_pass("1234"),
        mobile_number="9000000003",
        role=UserRole.FIELD_AGENT,
        is_first_login=False
    )
    db.session.add(worker_kaliselvan)
    
    # 4. Worker: Kannan (1221)
    worker_kannan = User(
        name="Kannan",
        pin_hash=hash_pass("1221"),
        mobile_number="9000000004",
        role=UserRole.FIELD_AGENT,
        is_first_login=False
    )
    db.session.add(worker_kannan)
    
    db.session.commit()
    print("Live test accounts created successfully.")
