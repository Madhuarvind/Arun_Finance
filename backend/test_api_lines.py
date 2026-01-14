import requests

base_url = "http://localhost:5000/api"

def test_get_all_lines():
    # Login as admin
    login_res = requests.post(f"{base_url}/auth/admin-login", json={
        "username": "admin",
        "password": "password" # Assuming default password
    })
    
    if login_res.status_code != 200:
        print(f"Login failed: {login_res.status_code} {login_res.text}")
        return

    token = login_res.json().get("access_token")
    print(f"Logged in, token: {token[:10]}...")

    # Fetch lines
    headers = {"Authorization": f"Bearer {token}"}
    lines_res = requests.get(f"{base_url}/line/all", headers=headers)
    
    print(f"Get All Lines: {lines_res.status_code}")
    print(lines_res.text)

if __name__ == "__main__":
    test_get_all_lines()
