import os
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, AudioNote, User, Customer, Loan
from utils.auth_helpers import get_user_by_identity
from datetime import datetime
import speech_recognition as sr
from pydub import AudioSegment

audio_bp = Blueprint("audio", __name__)

UPLOAD_FOLDER = os.path.join(os.getcwd(), "uploads", "audio")
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@audio_bp.route("/upload", methods=["POST"])
@jwt_required()
def upload_audio():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    
    if "file" not in request.files:
        return jsonify({"msg": "No file part"}), 400
        
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"msg": "No selected file"}), 400
        
    customer_id = request.form.get("customer_id")
    loan_id = request.form.get("loan_id")
    
    # Save file
    filename = f"{user.id}_{datetime.utcnow().timestamp()}.{file.filename.split('.')[-1]}"
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    file.save(file_path)
    
    transcription = ""
    sentiment = "neutral"
    
    # Process for STT
    try:
        # Convert to WAV if needed (e.g. m4a/aac from mobile)
        if not filename.endswith(".wav"):
            audio = AudioSegment.from_file(file_path)
            wav_path = file_path.rsplit(".", 1)[0] + ".wav"
            audio.export(wav_path, format="wav")
            process_path = wav_path
        else:
            process_path = file_path
            
        # STT Logic
        recognizer = sr.Recognizer()
        with sr.AudioFile(process_path) as source:
            audio_data = recognizer.record(source)
            # Using Google's free STT (Requires internet)
            transcription = recognizer.recognize_google(audio_data)
            
        # Basic Sentiment Detection
        lower_trans = transcription.lower()
        if any(word in lower_trans for word in ["problem", "difficult", "no money", "not now", "wait", "stress"]):
            sentiment = "distressed"
        elif any(word in lower_trans for word in ["moving", "address", "shifting", "new", "location"]):
            sentiment = "evasive"
            
    except Exception as e:
        print(f"STT Error: {str(e)}")
        transcription = f"[Transcription Failed: {str(e)}]"

    new_note = AudioNote(
        user_id=user.id,
        customer_id=customer_id if customer_id else None,
        loan_id=loan_id if loan_id else None,
        file_path=file_path,
        transcription=transcription,
        sentiment=sentiment
    )
    db.session.add(new_note)
    db.session.commit()
    
    return jsonify({
        "msg": "Audio note uploaded",
        "transcription": transcription,
        "sentiment": sentiment,
        "id": new_note.id
    }), 201

@audio_bp.route("/history", methods=["GET"])
@jwt_required()
def get_audio_history():
    customer_id = request.args.get("customer_id")
    if not customer_id:
        return jsonify({"msg": "customer_id required"}), 400
        
    notes = AudioNote.query.filter_by(customer_id=customer_id).order_by(AudioNote.created_at.desc()).all()
    return jsonify([{
        "id": n.id,
        "user_name": n.user.name,
        "transcription": n.transcription,
        "sentiment": n.sentiment,
        "created_at": n.created_at.isoformat()
    } for n in notes]), 200
