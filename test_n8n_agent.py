import requests
import json
import time

# YOUR N8N TEST URL
N8N_URL = "https://n8n-mxnm.onrender.com/webhook-test/validate-collection"

# Dummy Data (Modify this to test different scenarios)
payload = {
    "loan_id": 16,        # Ensure this ID exists in your backend
    "amount": 10.0,       # A very small amount to trigger "Abnormal Amount"
    "customer_id": 101
}

print(f"🚀 Sending Test Request to N8n: {N8N_URL}")
print(f"📦 Payload: {json.dumps(payload, indent=2)}")

try:
    response = requests.post(N8N_URL, json=payload, headers={"Content-Type": "application/json"})
    
    print(f"\n✅ Response Code: {response.status_code}")
    print(f"📄 Response Body: {response.text}")
    
    if response.status_code == 200:
        data = response.json()
        if data.get("status") == "warning":
            print("\n⚠️  AGENT WARNING RECEIVED:")
            print(f"   {data.get('message')}")
        else:
            print("\nOK: No warnings.")
    else:
        print("\n❌ Error: N8n returned an error.")

except Exception as e:
    print(f"\n❌ Connection Failed: {e}")
