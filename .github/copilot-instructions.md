# Copilot instructions — AeroWise Infrastructure

Get productive fast: architecture map, non-obvious commands, safety rails.

## Layout & architecture
- **`terraform/infra`** — Primary stack: VPC, EKS, AWS Load Balancer Controller, API Gateway + VPC Link, optional CloudFront CDN + WAF, RDS PostgreSQL, KMS, CloudTrail, GuardDuty, Inspector, Security Hub, VPC endpoints, NAT egress control. **Local `terraform.tfstate` is checked in—do not change backend or overwrite without approval.**
- **`terraform/edge`** — Demo/supplemental stack; consumes infra outputs via `data.terraform_remote_state` pointing at `../infra/terraform.tfstate`.
- **`terraform/modules/*`** — Local reusable modules. Key modules: `cdn` (CloudFront + S3 + OAC), `waf_cdn` (CloudFront WebACL), `waf_api` (regional WAF), `api-gateway` (HTTP API + VPC Link + authorizer), `eks` (cluster + nodegroup), `network` (VPC/subnets/NAT), `network-endpoints` (interface VPC endpoints for AWS services), `rds` (PostgreSQL), `db-secrets` (Secrets Manager), `kms-cmk`, `nat-egress-control`.
- **Security services**: CloudTrail (365-day retention), GuardDuty, Inspector (EC2/ECR/Lambda), Security Hub (CIS AWS Foundations Benchmark v3.0.0). All created in `terraform/infra/main.tf` with explicit dependencies.
- **`kubernetes/*`** — Sample internal app (`internal-app-deployment.yaml`) showing ALB Ingress usage. Real internal ALB is created by AWS Load Balancer Controller via Ingress annotation `alb.ingress.kubernetes.io/load-balancer-name: mobileapp-alb`.
- **Providers**: `kubernetes`/`helm` exec `aws eks get-token` via AWS CLI v2. EKS cluster auth required for any Terraform-triggered `kubectl`/Helm operations.

## Core workflows
- **Work inside stack dir**: `cd terraform/infra` (or `edge`). Typical flow:
  ```bash
  terraform init
  terraform fmt -recursive && terraform validate
  terraform plan -out=tfplan
  terraform show -json tfplan | jq .  # optional: inspect plan JSON
  terraform apply tfplan
  ```
- **Ingress-driven ALB**: Real internal ALB is created by AWS Load Balancer Controller from `mobileapp-alb` Ingress (see `kubernetes/internal-app-deployment.yaml` annotation). Terraform auto-discovers ALB via `data.kubernetes_ingress_v1.internal_app` and `data.aws_lb` in `terraform/infra/main.tf` when `enable_ingress_autodiscovery = true`.
- **API Gateway ↔ VPC Link ↔ ALB**: `module.api_gateway` in `terraform/infra/main.tf` wires API Gateway HTTP API routes to the internal ALB listener (`local.effective_alb_listener_arn`). Authorizer Lambda (`aws_lambda_function.api_authorizer`) is created inline and attached to protected routes.
  - Protected routes (require authorizer): `/assetservice`, `/flightservice`, `/paxservice`, `/notificationservice`
  - Public routes (no auth): `/authservice`, `/data`, `/broadcast`, `/client-login`, `/app-version/check`
- **Validation commands**:
  ```bash
  aws apigatewayv2 get-routes --api-id $(terraform output -raw api_id)
  curl -s $(terraform output -raw api_endpoint)/app-version/check
  kubectl run curl --image=curlimages/curl:8.5.0 -it --rm --restart=Never -- \
    curl -s $(terraform output -raw api_endpoint)/app-version/check
  ```
 
## Kubernetes integration & validation
- **ALB Ingress** (internal, target-type `ip`): see `kubernetes/internal-app-deployment.yaml` and `kubernetes/internal-app-targetgroupbinding.yaml`. Ingress annotation `alb.ingress.kubernetes.io/load-balancer-name: mobileapp-alb` creates the ALB named `mobileapp-alb`.
- **Load Balancer Controller**: configured by `helm_release.awsloadbalancercontroller` and `kubernetes_service_account_v1.aws_load_balancer_controller` in `terraform/infra/main.tf` with IRSA from `module.aws_lb_controller_irsa`.
- **Deployment flow**: 
  1. `terraform apply` creates EKS + Load Balancer Controller
  2. `kubectl apply -f kubernetes/internal-app-*.yaml` deploys app + Ingress
  3. Load Balancer Controller creates internal ALB from Ingress
  4. Terraform data sources auto-discover ALB (on next `plan`/`apply` with `enable_ingress_autodiscovery = true`)
- **Validate routes**: `aws apigatewayv2 get-routes --api-id $(terraform output -raw api_id)`
- **Test from internet**: `curl -s $(terraform output -raw api_endpoint)/app-version/check`
- **Test from pod**: `kubectl run curl --image=curlimages/curl:8.5.0 -it --rm --restart=Never -- curl -s $(terraform output -raw api_endpoint)/app-version/check`

## Flags & existing-resource patterns
- **Gating vars** in `terraform/infra/variables.tf`: `create_cdn`, `create_waf_api`, `create_waf_cdn`, `create_ecr_public_endpoint`, `create_aws_lb_controller_irsa`, `existing_vpc_id`, plus API/authorizer toggles.
- **Ingress ALB autodiscovery**: `enable_ingress_autodiscovery` controls whether `data.kubernetes_ingress_v1.internal_app` runs. Set `TF_VAR_enable_ingress_autodiscovery=false` (or the var in `terraform.tfvars`) when the EKS cluster/Ingress is not yet available so `terraform plan/refresh` does not call the Kubernetes API; leave `true` once the cluster and `mobileapp-alb` ingress exist so `local.effective_alb_listener_arn` can be auto-populated.
- **CDN & WAF:** When `create_cdn = true` and `create_waf_cdn = true`, `module.waf_cdn` (CloudFront-scope WebACL in `modules/waf_cdn`) is created and its ARN is passed into `module.cdn_static` as `web_acl_id`.
- **Authorizer:** In the current infra, the authorizer Lambda (`aws_lambda_function.api_authorizer`) is created in `terraform/infra/main.tf` and always attached to API routes via `module.api_gateway` (flags in `variables.tf` document a future optional, external-Lambda pattern).
- **Reusing existing IAM/Secrets**: set `aws_lb_controller_role_arn` or `lb_controller_role_name` to skip creating IRSA; pass existing Secrets/CloudTrail inputs in module variables instead of duplicating resources.
- **EKS IRSA/LB Controller**: if a role already exists, set the ARN/name; otherwise import (`terraform import 'module.aws_lb_controller_irsa[0].aws_iam_role.this' <arn>`). The ServiceAccount annotates to either the created IRSA role or the provided ARN.
- **VPC Endpoints**: `module.network_endpoints` intentionally does NOT consume EKS node security group to avoid circular dependencies. Explicit SG rule `aws_security_group_rule.vpce_allow_from_nodes` in `terraform/infra/main.tf` allows nodes to reach VPC endpoints on port 443.

## Deployment workflow (see `DEPLOYMENT_GUIDE.md` for full details)
- **Phase 1 (terraform apply):** From `terraform/infra`, apply to create VPC, EKS, Load Balancer Controller, API Gateway, RDS, security services, and optionally CDN + WAF (controlled via `terraform.tfvars`).
- **Phase 2 (kubectl apply):** Deploy Kubernetes app + Ingress (`kubernetes/internal-app-*.yaml`). AWS LB Controller creates the internal ALB and updates the Ingress status; Terraform data sources then discover the ALB hostname/listener.
- **Phase 3 (API validation):** Confirm API Gateway routes and ALB integration via `aws apigatewayv2 get-routes` and curl tests.
- **Phase 4 (CDN validation):** If `create_cdn`/`create_waf_cdn` are true, verify CloudFront distribution and WAF association (see WAF validation section below).

## Troubleshooting & imports
- EntityAlreadyExists for IAM: pass existing ARNs/names as above or import the role/policy, then re-plan.
- Secrets name in scheduled deletion: restore/import the existing secret or set `create_secrets = false` and pass `secret_arn` (RDS module).
- CloudTrail policy empty: check `modules/cloudtrail` inputs; ensure policy JSON is non-empty and rerun plan.
- API Gateway returns 502: if `enable_ingress_autodiscovery = false` or ALB not yet created, expected behavior. After Phase 2 (real ALB), verify health: `aws elbv2 describe-target-health --target-group-arn <TG_ARN>`.
- Use `terraform state list` to locate resource addresses before `terraform import`; re-run plan to ensure zero drift.
- Kubernetes/Helm stuck on hooks: run `terraform/infra/scripts/fast-cleanup.sh` (options to delete jobs/pods and patch namespace finalizers) before retrying destroy/uninstall.
- NAT Gateway deletion slow: expected (EIP cleanup takes several minutes). Set `retain_nat_eips = false` before destroy if needed.

## Safety & CI
- Escalate before touching state backend, committing new state files, running `terraform destroy`, or making wide IAM policy changes.
- CI expectations: `terraform fmt -check`, `terraform validate`, `terraform plan` (see `.github/workflows/terraform-checks.yml`). Vendored upstream module workflows live under `terraform/infra/.terraform/modules/*/`.
- **No manual steps during apply:** All ALB, API Gateway routes, and authorizer setup is automated. Errors indicate code/validation issues (catch with `terraform validate`).

## CDN WAF validation checklist
- Ensure `create_cdn = true` and `create_waf_cdn = true` in `terraform/infra/terraform.tfvars` (see example file). This enables `module.waf_cdn` and passes its `web_acl_arn` into `module.cdn_static`.
- Confirm plan/apply shows `aws_wafv2_web_acl.cdn` (from `terraform/modules/waf_cdn/main.tf`) and `aws_cloudfront_distribution.frontend` (from `terraform/modules/cdn/main.tf`), with `web_acl_id` on the distribution set to the WebACL ARN.
- After apply, verify association via AWS CLI:
	- `aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1`
	- `aws cloudfront list-distributions` and check the distribution’s `WebACLId` matches the WAF ARN.
- Use CloudWatch metrics configured in `aws_wafv2_web_acl.cdn.visibility_config` (metric `aerowise-<suffix>-waf-cdn`) to confirm the WAF is receiving traffic and counting blocked/allowed requests.

See `DEPLOYMENT_GUIDE.md` and `VERIFY_FLOW.md` for step-by-step runbook and flow validation.
