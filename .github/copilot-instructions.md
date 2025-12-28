<!-- Action-first guide for AI coding agents working on this Terraform repo -->
# Copilot instructions — terraform

Purpose: get productive fast—architecture map, non-obvious commands, safety rails.

## Layout & architecture
- `terraform/infra` — primary stack (VPC, EKS, ALB via Ingress, CDN/WAF toggles, RDS, KMS, CloudTrail, GuardDuty, Inspector, Security Hub, VPC endpoints, NAT egress). **Local `terraform.tfstate` is checked in—do not change backend or overwrite without approval.**
- `terraform/edge` — demo/supplemental stack; consumes infra outputs via `data.terraform_remote_state` pointing at `../infra/terraform.tfstate`.
- `terraform/modules/*` — local modules used by infra (see module READMEs); Helm tuning flags exposed for faster dev in `modules/network-policy`.
- Providers `kubernetes`/`helm` exec `aws eks get-token`; AWS CLI v2 and cluster auth are required for any `kubectl`/Helm operations triggered by Terraform.
- `kubernetes/*` contains a sample app (`internal-app`) showing ALB Ingress usage.

## Core workflows
- Work inside the stack dir: `cd terraform/infra` (or `edge`). Run `terraform init`, `terraform fmt -recursive && terraform validate`, `terraform plan -out=tfplan`, `terraform show -json tfplan | jq .`, `terraform apply tfplan`.
- API Gateway ↔ ALB via VPC Link (infra): enable `module.api_gateway` with `create_integration = true` and provide either `integration_uri` (e.g., `http://<alb-dns>:80`) or `alb_listener_arn`. Outputs: `api_endpoint`, `api_id`, `api_vpc_link_id`, `alb_http_listener_arn`.
- Validation: follow `terraform/infra/TEST_PLAN.md` (check outputs, `aws apigatewayv2 get-routes --api-id $(terraform output -raw api_id)`, curl `$(terraform output -raw api_endpoint)/<path>` from internet or from a `kubectl run` pod inside the cluster).
- Fast dev toggles: see `terraform/infra/terraform.tfvars.example` for Helm speed-ups (`network_policy_mobile_helm_*`) and examples like disabling NLB. Match new variables with tfvars/example entries when you add them.
 
 ## Kubernetes integration & validation
 - ALB Ingress (internal, target-type `ip`): see `kubernetes/internal-app-deployment.yaml` (paths `/` and `/app-version/check`).
 - Validate API Gateway routes: `aws apigatewayv2 get-routes --api-id $(terraform output -raw api_id)`.
 - Test endpoint from internet: `curl -s $(terraform output -raw api_endpoint)/app-version/check`.
 - Test from a pod: `kubectl run curl --image=curlimages/curl:8.5.0 -it --rm --restart=Never -- curl -s $(terraform output -raw api_endpoint)/app-version/check`.

## Flags & existing-resource patterns
- Gating vars: `create_api_gateway_integration`, `create_cdn`, `create_waf_api`, `create_waf_cdn`, `create_ecr_public_endpoint`, `create_aws_lb_controller_irsa`, `existing_vpc_id`.
- Prefer reusing existing IAM/Secrets resources: set `aws_lb_controller_role_arn` or `lb_controller_role_name` to skip creating IRSA; set `cloudtrail_role_arn` or `secret_arn` inputs where available instead of duplicating resources.
- EKS IRSA/LB Controller: if a role already exists, set the ARN/name; otherwise import (`terraform import 'module.aws_lb_controller_irsa[0].aws_iam_role.this' <arn>`). The ServiceAccount annotates to either the created IRSA role or the provided ARN.

## Troubleshooting & imports (from `terraform/infra/NOTES.md`)
- EntityAlreadyExists for IAM: pass existing ARNs/names as above or import the role/policy, then re-plan.
- Secrets name in scheduled deletion: restore/import the existing secret or set `create_secrets = false` and pass `secret_arn` (RDS module).
- CloudTrail policy empty: check `modules/cloudtrail` inputs; ensure policy JSON is non-empty and rerun plan.
- Use `terraform state list` to locate resource addresses before `terraform import`; re-run plan to ensure zero drift.
- Kubernetes/Helm stuck on hooks: run `terraform/infra/scripts/fast-cleanup.sh` (options to delete jobs/pods and patch namespace finalizers) before retrying destroy/uninstall.

## Safety & CI
- Escalate before touching state backend, committing new state files, running `terraform destroy`, or making wide IAM policy changes.
- CI expectations: `terraform fmt -check`, `terraform validate`, `terraform plan` (see `.github/workflows/terraform-checks.yml`). Vendored upstream module workflows live under `terraform/infra/.terraform/modules/*/`.

Questions/unclear areas? Point me at the module or stack you want clarified and I can extend this file with deeper examples.
