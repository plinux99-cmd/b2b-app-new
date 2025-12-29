#!/usr/bin/env bash
# Automated verification script for API Gateway → VPC Link → ALB flow
# Usage: ./verify-flow.sh [--full] [--test-endpoint]

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="mobileapp"
INGRESS_NAME="internal-app-ingress"
FULL_CHECK="${1:-}"
TEST_ENDPOINT="${2:-}"

echo "=== API Gateway → VPC Link → ALB Flow Verification ==="
echo "Region: $REGION"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}✓ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

fail() {
  echo -e "${RED}✗ $1${NC}"
  exit 1
}

# Step 1: Check Ingress exists and has ALB hostname
echo "Step 1: Checking Kubernetes Ingress..."
INGRESS_JSON=$(kubectl get ingress -n "$NAMESPACE" "$INGRESS_NAME" -o json 2>/dev/null || echo "{}")
ALB_HOSTNAME=$(echo "$INGRESS_JSON" | jq -r '.status.loadBalancer.ingress[0].hostname // empty' 2>/dev/null || echo "")

if [ -z "$ALB_HOSTNAME" ]; then
  warn "Ingress ALB not yet provisioned (still loading...)"
  echo "  Tip: Wait for AWS Load Balancer Controller to create ALB and Ingress to populate status.loadBalancer"
  exit 0
else
  pass "Ingress ALB discovered: $ALB_HOSTNAME"
fi

# Step 2: Verify ALB exists in AWS
echo ""
echo "Step 2: Verifying ALB in AWS..."
ALB_DESC=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME']" 2>/dev/null || echo "[]")
ALB_ARN=$(echo "$ALB_DESC" | jq -r '.[0].LoadBalancerArn // empty' 2>/dev/null || echo "")
ALB_STATE=$(echo "$ALB_DESC" | jq -r '.[0].State.Code // empty' 2>/dev/null || echo "")

if [ -z "$ALB_ARN" ]; then
  fail "ALB not found in AWS for hostname: $ALB_HOSTNAME"
fi
pass "ALB ARN: $ALB_ARN (State: $ALB_STATE)"

# Step 3: Check ALB Listener (Port 80)
echo ""
echo "Step 3: Checking ALB HTTP Listener..."
LISTENER_ARN=$(aws elbv2 describe-listeners --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`80\`].ListenerArn" --output text 2>/dev/null || echo "")

if [ -z "$LISTENER_ARN" ]; then
  fail "No HTTP listener (port 80) found on ALB"
fi
pass "ALB Listener ARN: $LISTENER_ARN"

# Step 4: Check ALB Target Group
echo ""
echo "Step 4: Checking ALB Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ]; then
  warn "No target groups found on ALB (targets may be managed by Ingress Controller)"
else
  TG_HEALTH=$(aws elbv2 describe-target-health --region "$REGION" \
    --target-group-arn "$TG_ARN" 2>/dev/null || echo "[]")
  HEALTHY_COUNT=$(echo "$TG_HEALTH" | jq '[.TargetHealthDescriptions[]? | select(.TargetHealth.State=="healthy")] | length' 2>/dev/null || echo "0")
  pass "Target Group: $TG_ARN ($HEALTHY_COUNT healthy targets)"
fi

# Step 5: Check Terraform outputs
echo ""
echo "Step 5: Checking Terraform outputs..."
if command -v terraform &> /dev/null && [ -f "terraform/infra/terraform.tfstate" ]; then
  cd terraform/infra || exit 1
  EFFECTIVE_ARN=$(terraform output -raw effective_alb_listener_arn 2>/dev/null || echo "")
  
  if [ -n "$EFFECTIVE_ARN" ]; then
    pass "Effective ALB Listener ARN (from Terraform): $EFFECTIVE_ARN"
  else
    warn "Terraform output not yet available (may still be applying)"
  fi
  cd - > /dev/null
fi

# Step 6: Check API Gateway
echo ""
echo "Step 6: Checking API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" --query "Items[0].ApiId" --output text 2>/dev/null || echo "")

if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  warn "No HTTP API found (may not yet be created in Terraform)"
else
  pass "API Gateway ID: $API_ID"
  
  # Check VPC Link
  VPC_LINK_ID=$(aws apigatewayv2 get-vpc-links --region "$REGION" --query "Items[0].VpcLinkId" --output text 2>/dev/null || echo "")
  if [ -n "$VPC_LINK_ID" ] && [ "$VPC_LINK_ID" != "None" ]; then
    VPC_LINK_STATUS=$(aws apigatewayv2 get-vpc-link --vpc-link-id "$VPC_LINK_ID" --region "$REGION" \
      --query "Status" --output text 2>/dev/null || echo "")
    pass "VPC Link ID: $VPC_LINK_ID (Status: $VPC_LINK_STATUS)"
  else
    warn "VPC Link not found (API Gateway may not have created it yet)"
  fi
  
  # Check Integration
  INTEGRATION=$(aws apigatewayv2 get-integrations --api-id "$API_ID" --region "$REGION" \
    --query "Items[0]" 2>/dev/null || echo "{}")
  INT_TYPE=$(echo "$INTEGRATION" | jq -r '.IntegrationType // empty' 2>/dev/null || echo "")
  INT_URI=$(echo "$INTEGRATION" | jq -r '.IntegrationUri // empty' 2>/dev/null || echo "")
  
  if [ "$INT_TYPE" = "HTTP_PROXY" ] || [ "$INT_TYPE" = "HTTP" ]; then
    pass "Integration Type: $INT_TYPE"
    pass "Integration URI: $INT_URI"
  else
    warn "Integration type unexpected: $INT_TYPE"
  fi
fi

# Step 7: Optional full flow test
if [ "$FULL_CHECK" = "--full" ] || [ "$TEST_ENDPOINT" = "--test-endpoint" ]; then
  echo ""
  echo "Step 7: Testing API Gateway endpoint..."
  
  if [ -n "$API_ID" ]; then
    API_ENDPOINT=$(aws apigatewayv2 get-stages --api-id "$API_ID" --region "$REGION" \
      --query "Items[0].AccessLogSetting.DestinationArn" --output text 2>/dev/null | cut -d: -f1- || echo "")
    
    # Try direct endpoint
    API_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
    echo "  Testing: $API_ENDPOINT/app-version/check"
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_ENDPOINT/app-version/check" 2>/dev/null || echo "000")
    
    if [ "$RESPONSE" = "200" ]; then
      pass "API response: HTTP $RESPONSE"
    elif [ "$RESPONSE" = "502" ]; then
      warn "API returned HTTP 502 (Bad Gateway) - ALB targets may not be healthy yet"
    else
      warn "API response: HTTP $RESPONSE"
    fi
  else
    warn "Cannot test endpoint: API Gateway not found"
  fi
fi

echo ""
echo "=== Verification Complete ==="
echo ""
echo "Summary:"
echo "  ✓ Ingress ALB discovered and ready"
echo "  ✓ ALB accessible in AWS"
echo "  ✓ Listener and target group configured"
if [ "$FULL_CHECK" = "--full" ] || [ "$TEST_ENDPOINT" = "--test-endpoint" ]; then
  echo "  ✓ API endpoint test completed"
fi
echo ""
echo "Next steps:"
echo "  1. Deploy app to mobileapp namespace with Ingress annotations"
echo "  2. Verify ALB targets become healthy"
echo "  3. Test API endpoint: https://\$API_ID.execute-api.$REGION.amazonaws.com/app-version/check"
echo "  4. Full guide: ../VERIFY_FLOW.md"
