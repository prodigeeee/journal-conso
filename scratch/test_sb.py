import requests

url = "https://aswxkjibvcadnwujzwcm.supabase.co/rest/v1/site_content"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

# Test a write
data = {"key": "test_connection", "value": "Writing from AI"}
response = requests.post(url, json=data, headers=headers)

print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
