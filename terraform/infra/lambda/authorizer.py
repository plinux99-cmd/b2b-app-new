import json


def handler(event, context):
    """
    Lambda authorizer for API Gateway v2 (HTTP API)
    Payload format version: 2.0
    
    Authorization logic:
    - If Authorization header is present: Allow request
    - Otherwise: Deny request
    """
    
    # Extract headers (case-insensitive)
    headers = event.get("headers") or {}
    token = headers.get("authorization")
    
    # API Gateway v2 requires this response format
    if not token:
        return {
            "isAuthorized": False
        }
    
    # Allow request when token is present
    # Extend with real validation logic as needed
    return {
        "isAuthorized": True,
        "context": {
            "principalId": "user",
            "username": "authenticated-user"
        }
    }
