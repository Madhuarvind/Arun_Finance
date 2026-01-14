import requests

print("Attempting to seed Remote Database on Render...")

url = "https://vasool-drive-backend.onrender.com/api/admin/seed-users"

try:
    response = requests.post(url)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code == 200:
        print("\nSUCCESS! Database has been seeded.")
        print("You can now login with:")
        print("Admin: Arun / Arun@123")
        print("Worker: Madhu / 1111")
    else:
        print("\nFAILED. Please ensure the backend is deployed (Green status on Render).")

except Exception as e:
    print(f"Error: {e}")
