#!/usr/bin/env python3
import calendar
import os
import sys
import json
import google.auth.transport.requests
import google.oauth2.service_account

def get_token(json_str):
    try:
        # Load the string into a dictionary
        info = json.loads(json_str)
        
        # Initialize credentials
        creds = google.oauth2.service_account.Credentials.from_service_account_info(info)
        scoped_creds = creds.with_scopes(['https://www.googleapis.com/auth/cloud-platform'])
        
        # Refresh to get the access token
        request = google.auth.transport.requests.Request()
        scoped_creds.refresh(request)

        token = scoped_creds.token
        expiry = int(calendar.timegm(scoped_creds.expiry.utctimetuple()))
        
        print(json.dumps({
            "token": token,
            "expiry": expiry
        }))

    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}\n")
        sys.exit(1)

if __name__ == "__main__":
    # Prefer the environment (SERVICE_KEY_CONTENT) so the private key never appears on
    # this process's argv (/proc/<pid>/cmdline is world-readable). Fall back to argv for
    # manual/CLI use.
    json_str = os.environ.get("SERVICE_KEY_CONTENT")
    if not json_str and len(sys.argv) >= 2:
        json_str = sys.argv[1]
    if not json_str:
        sys.stderr.write("Usage: SERVICE_KEY_CONTENT=<json> token_from_key.py  (or pass the json as arg 1)\n")
        sys.exit(1)

    get_token(json_str)
