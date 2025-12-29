# Terraform Deployment Guide — Dummy ALB to Real ALB Transition

## Overview

This Terraform stack now uses a **dummy (placeholder) ALB** for API Gateway integration during initial deployment. This approach ensures:
- ✅ **Error-free execution** with no manual ALB setup needed
- ✅ **Immediate API Gateway endpoint** live from `terraform apply`
- ✅ **Seamless transition** to real Kubernetes-managed ALB post-deployment
- ✅ **No downtime** when switching to real ALB

## Phase 1: Initial Deployment (with Dummy ALB)

### Prerequisites
- AWS credentials configured (`aws configure` or environment variables)
- Terraform `>= 1.5`
- `terraform/infra/terraform.tfvars` configured with your settings

### Execute apply
```bash
cd terraform/infra

# Format and validate
terraform fmt -recursive && terraform validate

# Plan (inspect changes)
terraform plan -out=tfplan

# Apply (creates dummy ALB, API Gateway, EKS cluster, RDS, etc.)
terraform apply tfplan
```

### Verify Phase 1
```bash
# Get API Gateway endpoint (functional with dummy ALB backend)
terraform output -raw api_endpoint

# Test API endpoint
curl -s https://$(terraform output -raw api_endpoint)/app-version/check

# Verify API Gateway routes created
aws apigatewayv2 get-routes --api-id $(terraform output -raw api_id)
```

**At this point:**
- ✅ Dummy ALB is ready (target group configured but no healthy targets yet)
- ✅ API Gateway is live with routes to dummy ALB
- ✅ EKS cluster is provisioning
- ✅ RDS, KMS, CloudTrail, and security services are deployed

---

## Phase 2: Kubernetes Deployment (Deploy Real Workload)

### Prerequisites
- EKS cluster ready: `aws eks describe-cluster --name $(terraform output -raw eks_cluster_name)`
- `kubectl` configured: `aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region us-east-1`

### Deploy sample app with Ingress
```bash
cd kubernetes

# Deploy app and Ingress
kubectl apply -f internal-app-deployment.yaml
kubectl apply -f internal-app-targetgroupbinding.yaml

# Wait for Ingress ALB to be created
kubectl get ingress internal-app-ingress -n mobileapp -w

# Once Ingress shows EXTERNAL-IP, get the real ALB DNS
REAL_ALB_DNS=$(kubectl get ingress internal-app-ingress -n mobileapp -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
echo "Real ALB DNS: $REAL_ALB_DNS"
```

### Verify Phase 2
```bash
# Check ALB health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names k8s-mobileap-* --query 'TargetGroups[0].TargetGroupArn' --output text)

# Test real ALB directly
curl -s http://$REAL_ALB_DNS/app-version/check
```

**At this point:**
- ✅ Kubernetes app is running
- ✅ AWS Load Balancer Controller discovered Ingress and created real internal ALB
- ✅ Target group has healthy Kubernetes pods
- ✅ Real ALB is ready but API Gateway still points to dummy ALB

---

## Phase 3: Update API Gateway to Real ALB (Zero-Downtime Cutover)

### Update terraform.tfvars
```hcl
# Before:
integration_uri = "http://dummy-alb-internal.local:80"

# After (replace with real ALB DNS from Phase 2):
integration_uri = "http://<REAL_ALB_DNS>:80"

# Example:
integration_uri = "http://k8s-mobileap-internal-63a6eb7efe-1234567.elb.us-east-1.amazonaws.com:80"
```

### Plan and apply
```bash
cd terraform/infra

# Validate syntax
terraform fmt -recursive && terraform validate

# Plan the change
terraform plan -out=tfplan

# Review plan (should show API Gateway integration URI update only)
terraform show tfplan | grep -A 10 "integration_uri"

# Apply
terraform apply tfplan
```

### Verify Phase 3
```bash
# Confirm API Gateway now points to real ALB
aws apigatewayv2 get-integration \
  --api-id $(terraform output -raw api_id) \
  --integration-id $(aws apigatewayv2 get-integrations --api-id $(terraform output -raw api_id) --query 'Items[0].IntegrationId' --output text) \
  | jq '.IntegrationUri'

# Test API endpoint (now hitting real ALB)
curl -s https://$(terraform output -raw api_endpoint)/app-version/check
```

**At this point:**
- ✅ API Gateway integration updated to real ALB
- ✅ Traffic flows: API Gateway → VPC Link → Real ALB → Kubernetes pods
- ✅ No downtime during cutover

---

## Phase 4: Clean Up (Optional)

### Option A: Remove dummy ALB
```bash
cd terraform/infra

# Destroy only the dummy ALB
terraform destroy -target=module.dummy_alb
```

### Option B: Keep dummy ALB as fallback
```bash
# No action needed; dummy ALB remains (minimal cost)
# If needed later, update terraform.tfvars back to:
# integration_uri = "http://dummy-alb-internal.local:80"
```

---

## Troubleshooting

### API endpoint returns 502 or 504
- **Dummy ALB phase:** Dummy target group has no targets; expected until real ALB is created
- **Real ALB phase:** Check target health:
  ```bash
  aws elbv2 describe-target-health --target-group-arn <TG_ARN>
  ```

### Ingress ALB not created
- Ensure AWS Load Balancer Controller IRSA is deployed:
  ```bash
  kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
  ```
- Check controller logs:
  ```bash
  kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  ```

### Integration URI mismatch
- Verify real ALB DNS:
  ```bash
  aws elbv2 describe-load-balancers --query 'LoadBalancers[?Tags[?Key==`Name` && Value==`k8s-mobileap-*`]].DNSName'
  ```
- Ensure no trailing `/` in `integration_uri`

### Terraform state drift
- Always run `terraform plan` before `terraform apply` to check for external changes
- If dummy ALB is deleted externally, `terraform plan` will show it for recreation

---

## Summary: Phase Timeline

| Phase | Duration | Action | Output |
|-------|----------|--------|--------|
| 1 | ~15-20 min | `terraform apply` | Dummy ALB + API GW + EKS | `api_endpoint` live |
| 2 | ~10-15 min | Deploy Kubernetes + Ingress | Real ALB created | `REAL_ALB_DNS` ready |
| 3 | ~2 min | Update `integration_uri` + apply | API GW updated | Traffic flows to real ALB |
| 4 | ~5 min | `terraform destroy -target=module.dummy_alb` | Dummy ALB removed | Cleanup complete |

**Total time to production:** ~35-45 minutes (Phase 1 + 2 + 3)

---

## Key Configuration Files

- **Main Terraform:** `terraform/infra/main.tf` (dummy ALB module, API GW module)
- **Variables:** `terraform/infra/variables.tf` (integration_uri, create_authorizer)
- **Values:** `terraform/infra/terraform.tfvars` (edit here to switch ALBs)
- **Kubernetes:** `kubernetes/internal-app-deployment.yaml`, `kubernetes/internal-app-targetgroupbinding.yaml`

---

## FAQ

**Q: Do I need to create an ALB manually?**  
A: No. Terraform creates a dummy ALB automatically. Kubernetes creates the real ALB via Ingress Controller.

**Q: Can I use the API endpoint during Phase 1?**  
A: Yes, but responses will be 502/504 until Phase 2 (dummy ALB has no targets). Once Phase 2 is complete, responses will be 200/OK.

**Q: Is there downtime when switching from dummy to real ALB?**  
A: No. Updating `integration_uri` and re-applying is instantaneous (API Gateway parameter update).

**Q: Can I skip the dummy ALB phase?**  
A: No. The dummy ALB ensures Terraform completes without errors. You must know the real ALB DNS before apply, which requires Kubernetes to be deployed first (circular dependency).

**Q: What if I want to update the real ALB DNS later?**  
A: Edit `terraform.tfvars` again with the new DNS, run `terraform plan`, and apply. No other resources are affected.

**Q: Can I have multiple ALBs?**  
A: Yes. The dummy ALB is just a placeholder. You can have multiple real ALBs and update `integration_uri` to any of them.
