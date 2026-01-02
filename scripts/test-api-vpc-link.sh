#!/bin/bash

# API VPC Link Testing Script
# Tests all service endpoints through API Gateway

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "API VPC Link Verification"
echo "======================================"
echo ""

# Get API endpoint
API_ENDPOINT=$(cd terraform/infra && terraform output -raw api_endpoint 2>/dev/null || echo "")

if [ -z "$API_ENDPOINT" ]; then
  echo -e "${RED}❌ Error: Could not retrieve API endpoint${NC}"
  echo "Make sure you're in the project root and terraform outputs are available"
  exit 1
fi

echo -e "${YELLOW}API Endpoint:${NC} $API_ENDPOINT"
echo ""

# Define test endpoints
declare -A ENDPOINTS=(
  ["/assetservice"]="Protected - Asset Service"
  ["/flightservice"]="Protected - Flight Service"
  ["/paxservice"]="Protected - Pax Service"
  ["/notificationservice"]="Protected - Notification Service"
  ["/authservice"]="Public - Auth Service"
  ["/data"]="Public - Data Service"
  ["/broadcast"]="Public - Broadcast Service"
  ["/client-login"]="Public - Client Login Service"
  ["/app-version/check"]="Public - App Version Check"
)

PASSED=0
FAILED=0

echo "Testing Endpoints:"
echo "=================="
echo ""

for endpoint in "${!ENDPOINTS[@]}"; do
  description="${ENDPOINTS[$endpoint]}"
  url="$API_ENDPOINT$endpoint"
  
  echo -n "Testing: $endpoint ($description) ... "
  
  # Test with 5 second timeout
  response=$(curl -s -w "\n%{http_code}" -o /dev/null --max-time 5 "$url" 2>/dev/null || echo "000")
  http_code="${response##*$'\n'}"
  
  # Check if response is successful (2xx or 3xx) or if it's a 401 (auth required)
  if [[ "$http_code" =~ ^(200|301|302|401|403)$ ]]; then
    echo -e "${GREEN}✓ OK (HTTP $http_code)${NC}"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAILED (HTTP $http_code)${NC}"
    ((FAILED++))
  fi
done

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All endpoints are responding!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some endpoints failed. Check API Gateway routes and ALB health.${NC}"
  echo ""
  echo "Troubleshooting steps:"
  echo "1. Check ALB health:"
  echo "   kubectl get ingress -n mobileapp mobileapp-alb"
  echo ""
  echo "2. Check target health:"
  echo "   aws elbv2 describe-target-health --target-group-arn <TG_ARN>"
  echo ""
  echo "3. Check API Gateway routes:"
  echo "   aws apigatewayv2 get-routes --api-id \$(terraform output -raw api_id)"
  echo ""
  echo "4. Check VPC Link status:"
  echo "   aws ec2-v2 describe-vpc-links"
  exit 1
fi
