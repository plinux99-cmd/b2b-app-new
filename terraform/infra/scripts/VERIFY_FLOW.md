# API Gateway → VPC Link → ALB Flow Verification

This guide walks through the complete end-to-end flow verification after Terraform applies.

## Prerequisites
- EKS cluster running
- AWS Load Balancer Controller deployed
- Kubernetes Ingress for `internal-app` in `mobileapp` namespace created
- Terraform apply completed successfully

## Phase 1: Verify Infrastructure Readiness

### 1. Check EKS Cluster Status
```bash
EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
aws eks describe-cluster --name "$EKS_CLUSTER" --query 'cluster.status'
```
**Expected Output:** `ACTIVE`

### 2. Check Kubernetes Ingress Status
```bash
kubectl get ingress -n mobileapp internal-app-ingress -o json | \
  jq '.status.loadBalancer.ingress[0].hostname'
```
**Expected Output:** ALB DNS name (e.g., `k8s-mobileap-internal-*.elb.us-east-1.amazonaws.com`)

### 3. Verify ALB Auto-Discovery
```bash
ALB_HOSTNAME=$(kubectl get ingress -n mobileapp internal-app-ingress -o json | \
  jq -r '.status.loadBalancer.ingress[0].hostname')
  
aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME']" | \
  jq '.LoadBalancers[0] | {Name, Arn, State: .State.Code}'
```
**Expected Output:** Active ALB with Arn

### 4. Verify ALB Listener
```bash
ALB_ARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME'].LoadBalancerArn" --output text)
aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[?Port==`80`]' | \
  jq '.Listeners[0] | {Port, Protocol, ListenerArn}'
```
**Expected Output:** Port 80 listener with ARN (used by API Gateway)

## Phase 2: Verify Terraform Outputs

### 5. Check Auto-Discovered ALB Details
```bash
cd terraform/infra
terraform output -json | jq '{
  ingress_alb_hostname: .ingress_alb_hostname.value,
  ingress_alb_arn: .ingress_alb_arn.value,
  alb_http_listener_arn: .alb_http_listener_arn.value,
  effective_alb_listener_arn: .effective_alb_listener_arn.value
}'
```
**Expected Output:**
```json
{
  "ingress_alb_hostname": "k8s-mobileap-internal-*.elb.us-east-1.amazonaws.com",
  "ingress_alb_arn": "arn:aws:elasticloadbalancing:us-east-1:*:loadbalancer/app/...",
  "alb_http_listener_arn": "arn:aws:elasticloadbalancing:us-east-1:*:listener/app/...",
  "effective_alb_listener_arn": "arn:aws:elasticloadbalancing:us-east-1:*:listener/app/..."
}
```

## Phase 3: Verify API Gateway Integration

### 6. Check API Gateway VPC Link
```bash
API_ID=$(terraform output -raw api_id 2>/dev/null || echo "")
if [ -n "$API_ID" ]; then
  aws apigatewayv2 get-apis --query "Items[?ApiId=='$API_ID']" | \
    jq '.Items[0] | {ApiId, Name, ProtocolType}'
fi
```
**Expected Output:** HTTP API

### 7. Check VPC Link Status
```bash
VPC_LINK_ID=$(aws apigatewayv2 get-vpc-links --query 'Items[0].VpcLinkId' --output text 2>/dev/null || echo "")
if [ -n "$VPC_LINK_ID" ] && [ "$VPC_LINK_ID" != "None" ]; then
  aws apigatewayv2 get-vpc-link --vpc-link-id "$VPC_LINK_ID" | \
    jq '{VpcLinkId, Name, Status: .Status, SubnetIds: .SubnetIds}'
fi
```
**Expected Output:** VPC Link in `AVAILABLE` status

### 8. Check API Gateway Integration
```bash
if [ -n "$API_ID" ]; then
  aws apigatewayv2 get-integrations --api-id "$API_ID" --query 'Items[0]' | \
    jq '{IntegrationId, IntegrationType, Uri: .IntegrationUri, VpcLink: .VpcLinkId}'
fi
```
**Expected Output:** Integration with `VPC_LINK` type and listener ARN as URI

### 9. Check API Gateway Routes
```bash
if [ -n "$API_ID" ]; then
  aws apigatewayv2 get-routes --api-id "$API_ID" --query 'Items' | \
    jq '.[] | {RouteKey, Target: .Target}'
fi
```
**Expected Output:** Routes mapped to the VPC Link integration (e.g., `GET /`, `GET /app-version/check`)

## Phase 4: End-to-End Flow Test

### 10. Get API Endpoint
```bash
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
echo "API Endpoint: $API_ENDPOINT"
```

### 11. Test from Internet (Public Route)
```bash
if [ -n "$API_ENDPOINT" ]; then
  curl -s "$API_ENDPOINT/app-version/check" | jq . || echo "Response received (may be plain text)"
fi
```
**Expected Output:** Response from the backend app (via ALB)

### 12. Test from Inside EKS Pod
```bash
kubectl run curl-test --image=curlimages/curl:8.5.0 -it --rm --restart=Never -- \
  curl -s "$API_ENDPOINT/app-version/check"
```
**Expected Output:** Same as above, confirming internal routing through VPC Link

### 13. Verify VPC Link Traffic (CloudWatch Logs)
```bash
VPC_LINK_SG=$(terraform output -raw vpc_link_sg_id 2>/dev/null || echo "")
if [ -n "$VPC_LINK_SG" ]; then
  aws ec2 describe-security-groups --group-ids "$VPC_LINK_SG" --query 'SecurityGroups[0].IpPermissions' | \
    jq '.[] | {FromPort, ToPort, IpProtocol, SourceSecurityGroupId}'
fi
```
**Expected Output:** Security group rules allowing inbound traffic from ALB SG to VPC Link

## Phase 5: Troubleshooting

### If API returns 502 Bad Gateway
1. Check ALB target health:
   ```bash
   ALB_ARN=$(terraform output -raw ingress_alb_arn 2>/dev/null || echo "")
   aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[0].TargetGroupArn' --output text | \
     xargs -I {} aws elbv2 describe-target-health --target-group-arn {}
   ```
   **Expected:** Targets in `healthy` state

2. Check VPC Link connectivity:
   ```bash
   aws apigatewayv2 get-vpc-link --vpc-link-id "$VPC_LINK_ID" | jq '.Status'
   ```
   **Expected:** `AVAILABLE`

3. Check ALB listener configuration:
   ```bash
   LISTENER_ARN=$(terraform output -raw alb_http_listener_arn 2>/dev/null || echo "")
   aws elbv2 describe-listeners --listener-arns "$LISTENER_ARN" | \
     jq '.Listeners[0] | {Port, Protocol, DefaultActions}'
   ```

### If Ingress ALB is not discovered
1. Verify Ingress status:
   ```bash
   kubectl get ingress -n mobileapp internal-app-ingress -o json | jq '.status'
   ```
   If empty, ALB Controller hasn't provisioned the ALB yet. Wait and check again.

2. Verify AWS Load Balancer Controller is running:
   ```bash
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   ```

3. Check Ingress annotations:
   ```bash
   kubectl get ingress -n mobileapp internal-app-ingress -o json | jq '.metadata.annotations'
   ```
   Should include `alb.ingress.kubernetes.io/scheme: internal`, etc.

## Summary

Once all 13 steps succeed, your flow is verified:
```
Internet Client
    ↓
API Gateway (HTTP API)
    ↓
VPC Link (ENIs in private subnets)
    ↓
Internal ALB (Kubernetes-managed)
    ↓
Target Group
    ↓
EKS Pods (internal-app)
```

All traffic is private—no internet-facing ALB resources.
