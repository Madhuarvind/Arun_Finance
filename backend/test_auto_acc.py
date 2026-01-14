import requests
import json

url = "http://localhost:5000/api/reports/auto-accounting"
response = requests.get(url)

print(f"Status: {response.statusCode if hasattr(response, 'statusCode') else response.status_code}")
print(f"Content: {response.text}")
