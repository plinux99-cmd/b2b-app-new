import json
import logging
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# SECURITY: Configure valid tokens/API keys here or retrieve from Secrets Manager
# For production, use AWS Secrets Manager or implement JWT validation
VALID_TOKENS = {
    "test-token",  # Demo token - replace with real validation
    # Add more valid tokens or implement JWT validation
}

def validate_token(token):
    """
    Validate the authorization token.
    
    PRODUCTION TODO:
    - Implement JWT validation (decode, verify signature, check expiration)
    - Query API key database or cache
    - Integrate with AWS Cognito or other IdP
    - Check token against Secrets Manager or Parameter Store
    
    Current implementation: Simple token allowlist (demo only)
    """
    if not token:
        return False
    
    # Remove 'Bearer ' prefix if present
    if token.startswith("Bearer "):
        token = token[7:]
    
    # Demo: Check against allowlist
    # PRODUCTION: Replace with real JWT validation
    if token in VALID_TOKENS:
        return True
    
    # Additional validation logic can be added here
    logger.warning(f"Invalid token attempted: {token[:10]}...")
    return False


def handler(event, context):
    """
    Lambda authorizer for API Gateway v2 (HTTP API)
    Payload format version: 2.0
    Simple responses enabled
    
    SECURITY: Validates authorization tokens before allowing API access
    """
    
    try:
        # Extract headers (API Gateway v2 normalizes to lowercase)
        headers = event.get("headers") or {}
        token = headers.get("authorization", "")
        
        # Log request metadata (not the full token for security)
        request_id = event.get("requestContext", {}).get("requestId", "unknown")
        route_key = event.get("requestContext", {}).get("http", {}).get("path", "unknown")
        logger.info(f"Authorization request - RequestID: {request_id}, Path: {route_key}")
        
        # Validate token
        if not token:
            logger.warning(f"No authorization token - RequestID: {request_id}")
            return {"isAuthorized": False}
        
        # Perform token validation
        is_valid = validate_token(token)
        
        if is_valid:
            logger.info(f"Authorization successful - RequestID: {request_id}")
            return {"isAuthorized": True}
        else:
            logger.warning(f"Authorization failed - RequestID: {request_id}")
            return {"isAuthorized": False}
    
    except Exception as e:
        logger.error(f"Authorization error: {str(e)}")
        # Fail closed - deny on errors
        return {"isAuthorized": False}
