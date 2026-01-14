from app import create_app
from models import Loan

app = create_app()
with app.app_context():
    l = Loan.query.get(1)
    if l:
        print(f"Loan ID 1 Details:")
        print(f"Principal: {l.principal_amount}")
        print(f"Pending: {l.pending_amount}")
    else:
        print("Loan ID 1 not found")
