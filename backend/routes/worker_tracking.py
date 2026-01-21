from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, UserRole, LocationLog
from datetime import datetime
from utils.auth_helpers import get_user_by_identity

tracking_bp = Blueprint("tracking", __name__)

@tracking_bp.route("/update-tracking", methods=["POST"])
@jwt_required()
def update_tracking():
    """Update field agent's current location and status"""
    identity = get_jwt_identity()
    data = request.get_json()
    
    # Resolve user from identity safely
    user = get_user_by_identity(identity)
    
    if not user:
        return jsonify({"msg": "user_not_found"}), 404
        
    user.last_latitude = data.get("latitude")
    user.last_longitude = data.get("longitude")
    user.last_location_update = datetime.utcnow()
    
    if "duty_status" in data:
        user.duty_status = data["duty_status"]
        
    activity = data.get("activity", "moving")
    if "activity" in data:
        user.current_activity = activity
    
    # Save to History Log
    log = LocationLog(
        user_id=user.id,
        latitude=user.last_latitude,
        longitude=user.last_longitude,
        activity=activity,
        timestamp=user.last_location_update
    )
    db.session.add(log)
    
    db.session.commit()
    return jsonify({"msg": "tracking_updated", "status": user.duty_status}), 200

@tracking_bp.route("/agent-history/<int:agent_id>", methods=["GET"])
@jwt_required()
def get_agent_history(agent_id):
    """Retrieve tracking history for a specific agent (Admin only)"""
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)
    
    if not admin:
        return jsonify({"msg": "unauthorized"}), 403
        
    date_str = request.args.get("date") # Optional date filter YYYY-MM-DD
    
    query = LocationLog.query.filter_by(user_id=agent_id)
    
    if date_str:
        target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        query = query.filter(db.func.date(LocationLog.timestamp) == target_date)
    
    history = query.order_by(LocationLog.timestamp.asc()).all()
    
    result = []
    for log in history:
        result.append({
            "latitude": log.latitude,
            "longitude": log.longitude,
            "timestamp": log.timestamp.isoformat(),
            "activity": log.activity
        })
        
    return jsonify(result), 200

@tracking_bp.route("/field-map", methods=["GET"])
@jwt_required()
def get_field_map():
    """Get all agents' last known positions (Admin only)"""
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)
    
    if not admin:
        return jsonify({"msg": "unauthorized"}), 403
        
    # Robust Role Check (Handle Enum, String, Case)
    role_val = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if role_val.lower() not in ['admin', 'superadmin']:
        return jsonify({"msg": "unauthorized"}), 403
        
    # Query agents more robustly (handle enum vs string)
    # Safe for Postgres Enum types
    agents = User.query.filter(User.role == UserRole.FIELD_AGENT).all()
    
    result = []
    for agent in agents:
        result.append({
            "id": agent.id,
            "name": agent.name,
            "mobile": agent.mobile_number,
            "latitude": agent.last_latitude,
            "longitude": agent.last_longitude,
            "last_update": agent.last_location_update.isoformat() if agent.last_location_update else None,
            "status": agent.duty_status,
            "activity": agent.current_activity
        })
        
    return jsonify(result), 200

@tracking_bp.route("/self-enroll-biometric", methods=["POST"])
@jwt_required()
def self_enroll_biometric():
    """Worker self-enrollment of face data"""
    try:
        identity = get_jwt_identity()
        user = get_user_by_identity(identity)
        
        if not user:
            return jsonify({"msg": "user_not_found"}), 404
            
        data = request.get_json()
        embedding = data.get("embedding")
        device_id = data.get("device_id")
        
        if not embedding:
            return jsonify({"msg": "missing_embedding"}), 400
            
        from models import FaceEmbedding, Device
        
        # Remove old embedding
        FaceEmbedding.query.filter_by(user_id=user.id).delete()
        
        new_face = FaceEmbedding(
            user_id=user.id,
            embedding_data=embedding,
            device_id=device_id
        )
        db.session.add(new_face)
        
        # Also trust this device if provided
        if device_id:
            device = Device.query.filter_by(user_id=user.id, device_id=device_id).first()
            if not device:
                device = Device(
                    user_id=user.id,
                    device_id=device_id,
                    device_name="Worker Device",
                    is_trusted=True
                )
                db.session.add(device)
            else:
                device.is_trusted = True
                device.last_active = datetime.utcnow()
        
        db.session.commit()
        return jsonify({"msg": "face_enrolled"}), 200
        
    except Exception as e:
        print(f"Enrollment Error: {e}")
        return jsonify({"msg": "server_error", "error": str(e)}), 500
