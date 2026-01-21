import cv2
import numpy as np
import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image


# Initialize MobileNetV2 as a feature extractor
# We use a pre-trained model and remove the classifier to get embeddings
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = models.mobilenet_v2(pretrained=True)
model.classifier = torch.nn.Identity()  # Remove the last layer
model.to(device)
model.eval()

# Face Detector Initialized globally for performance
face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# Image Transforms for MobileNet
transform = transforms.Compose(
    [
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ]
)


def generate_face_embedding(image_bytes):
    """
    1. Detect face using OpenCV Haar Cascade (Low Memory).
    2. Preprocess and generate 1280-d embedding using MobileNetV2.
    """
    import time

    start_time = time.time()
    try:
        # Load image
        img_array = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        if img is None:
            return None, "Invalid image data"

        # Performance: Scale down image for detection
        height, width = img.shape[:2]
        max_dim = 600
        if max(height, width) > max_dim:
            scale = max_dim / max(height, width)
            img_small = cv2.resize(img, (int(width * scale), int(height * scale)))
        else:
            img_small = img

        gray = cv2.cvtColor(img_small, cv2.COLOR_BGR2GRAY)
        
        # 1. OpenCV Haar Cascade Detection (Fast & Memory Efficient)
        faces = face_cascade.detectMultiScale(gray, 1.1, 5, minSize=(60, 60))
        
        face_img = None
        if len(faces) > 0:
            # Take the largest face
            x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
            # Scale coordinates back to original image size
            if max(height, width) > max_dim:
                x, y, w, h = int(x/scale), int(y/scale), int(w/scale), int(h/scale)
            
            # Crop with small padding
            pad_h = int(h * 0.1)
            pad_w = int(w * 0.1)
            y1, y2 = max(0, y-pad_h), min(height, y+h+pad_h)
            x1, x2 = max(0, x-pad_w), min(width, x+w+pad_w)
            face_img = img[y1:y2, x1:x2]

        if face_img is None or face_img.size == 0:
            return None, "Could not isolate face clearly. Please try again in better lighting."

        # Convert to PIL for Torchvision
        face_rgb = cv2.cvtColor(face_img, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(face_rgb)

        # Preprocess and generate embedding
        input_tensor = transform(pil_img).unsqueeze(0).to(device)

        with torch.no_grad():
            embedding = model(input_tensor)

        embedding_list = embedding.cpu().numpy().flatten().tolist()
        return embedding_list, None

    except Exception as e:
        print(f"ERROR in generate_face_embedding: {str(e)}")
        return None, f"Face processing error: {str(e)}"


def compare_embeddings(emb1, emb2):
    """Cosine Similarity comparison"""
    a = np.array(emb1)
    b = np.array(emb2)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
