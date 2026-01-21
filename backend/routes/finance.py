from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, UserRole, Expense, ExpenseCategory, Collection
from datetime import datetime, timedelta
from utils.auth_helpers import get_user_by_identity
from sqlalchemy import func

finance_bp = Blueprint("finance", __name__)

@finance_bp.route("/expenses", methods=["POST"])
@jwt_required()
def add_expense():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    
    current_role = user.role.value if hasattr(user.role, 'value') else str(user.role)
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
        return jsonify({"msg": "Admin access required"}), 403
        
    data = request.get_json()
    category_str = data.get("category")
    amount = data.get("amount")
    description = data.get("description")
    date_str = data.get("date") # Optional: YYYY-MM-DD
    
    if not category_str or amount is None:
        return jsonify({"msg": "Category and amount are required"}), 400
        
    try:
        category = ExpenseCategory(category_str)
    except ValueError:
        return jsonify({"msg": "Invalid expense category"}), 400
        
    expense_date = datetime.utcnow().date()
    if date_str:
        expense_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        
    new_expense = Expense(
        category=category,
        amount=amount,
        description=description,
        recorded_by=user.id,
        expense_date=expense_date
    )
    db.session.add(new_expense)
    db.session.commit()
    
    return jsonify({"msg": "Expense recorded", "id": new_expense.id}), 201

@finance_bp.route("/pl-summary", methods=["GET"])
@jwt_required()
def get_pl_summary():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    
    current_role = user.role.value if hasattr(user.role, 'value') else str(user.role)
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
        return jsonify({"msg": "Admin access required"}), 403
        
    period = request.args.get("period", "today") # today, week, month, all
    
    now = datetime.utcnow()
    start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    if period == "week":
        start_date = start_date - timedelta(days=now.weekday())
    elif period == "month":
        start_date = start_date.replace(day=1)
    elif period == "all":
        start_date = datetime(2000, 1, 1)

    # 1. Total Revenue (Collections)
    total_revenue = db.session.query(func.sum(Collection.amount)).filter(
        Collection.created_at >= start_date
    ).scalar() or 0.0
    
    # 2. Total Expenses
    total_expenses = db.session.query(func.sum(Expense.amount)).filter(
        Expense.expense_date >= start_date.date()
    ).scalar() or 0.0
    
    # 3. Category Breakdown
    expenses_by_category = db.session.query(
        Expense.category, func.sum(Expense.amount)
    ).filter(
        Expense.expense_date >= start_date.date()
    ).group_by(Expense.category).all()
    
    breakdown = {}
    for cat, amt in expenses_by_category:
        breakdown[cat.value] = amt
        
    return jsonify({
        "period": period,
        "revenue": total_revenue,
        "expenses": total_expenses,
        "net_profit": total_revenue - total_expenses,
        "expense_breakdown": breakdown
    }), 200

@finance_bp.route("/expenses", methods=["GET"])
@jwt_required()
def get_expenses():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    
    current_role = user.role.value if hasattr(user.role, 'value') else str(user.role)
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
        return jsonify({"msg": "Admin access required"}), 403
        
    expenses = Expense.query.order_by(Expense.expense_date.desc()).limit(50).all()
    result = []
    for e in expenses:
        result.append({
            "id": e.id,
            "category": e.category.value,
            "amount": e.amount,
            "description": e.description,
            "date": e.expense_date.isoformat(),
            "recorded_by": e.recorder.name if e.recorder else "System"
        })
    return jsonify(result), 200
