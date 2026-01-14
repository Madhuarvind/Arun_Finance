from app import create_app
from extensions import db
from sqlalchemy import text

app = create_app()
with app.app_context():
    try:
        # Check if columns exist and add them if not
        columns_to_add = [
            ("last_latitude", "FLOAT"),
            ("last_longitude", "FLOAT"),
            ("last_location_update", "DATETIME"),
            ("duty_status", "VARCHAR(20)"),
            ("current_activity", "VARCHAR(100)"),
            ("last_biometric_login", "DATETIME")
        ]
        
        for col_name, col_type in columns_to_add:
            try:
                db.session.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                print(f"Added column: {col_name}")
            except Exception as e:
                if "Duplicate column name" in str(e):
                    print(f"Column {col_name} already exists.")
                else:
                    print(f"Error adding {col_name}: {e}")
        
        db.session.commit()
        print("Database schema updated successfully.")
    except Exception as e:
        print(f"Fatal error during migration: {e}")
