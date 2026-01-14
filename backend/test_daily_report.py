import requests
import json
from datetime import datetime

# We need an admin token. Let's find an admin user.
url_login = "http://localhost:5000/api/auth/admin-login"
login_data = {"username": "admin", "password": "admin123"} # Guessing from previous logic
r = requests.post(url_login, json=login_data)
if r.status_code != 200:
    print(f"Login failed: {r.text}")
    exit()

token = r.json().get("access_token")
headers = {"Authorization": f"Bearer {token}"}

today = datetime.now().strftime("%Y-%m-%d")
url_report = f"http://localhost:5000/api/reports/daily?start_date={today}T00:00:00&end_date={today}T23:59:59"
r = requests.get(url_report, headers=headers)

print(f"Status: {r.status_code}")
print(f"Content: {r.text}")
