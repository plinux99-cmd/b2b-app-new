# Execution Checklist (Customer Inputs)

Provide these before running `terraform apply` in a new account/env:

- Project
  - `project_name`: naming prefix (e.g., aerowise-prod)
  - `environment`: short env label (e.g., prod, staging)
  - `aws_region`: target region (e.g., us-east-1)

- Networking
  - `existing_vpc_id` (optional): if reusing a VPC instead of creating a new one

- EKS / Ingress
  - `ingress_alb_name`: must match `alb.ingress.kubernetes.io/load-balancer-name` set on the Ingress
  - EKS access: AWS CLI v2 credentials with permission to call `eks get-token`

- API Gateway ↔ VPC Link ↔ ALB
  - Set `create_api_gateway_integration = true`
  - Provide ONE of:
    - `integration_uri` = `http://<alb-dns>:80` (recommended), OR
    - `alb_listener_arn` = `arn:aws:elasticloadbalancing:<region>:<account>:listener/app/<name>/<lb-id>/<listener-id>`

- IAM for AWS Load Balancer Controller (IRSA)
  - If reusing existing role: provide `aws_lb_controller_role_arn` or `lb_controller_role_name`
  - If attaching existing policy in account: provide `lb_controller_policy_arn` (optional)

- RDS (PostgreSQL)
  - `db_username`, `db_password` (or confirm secrets flow via Secrets Manager)

- Optional – API Custom Domain
  - `create_custom_domain = true`
  - `custom_domain_name` (DNS under your Hosted Zone)
  - `custom_domain_acm_cert_arn` (REGIONAL cert in API region)

- Optional – CDN (CloudFront)
  - `create_cdn = true`
  - `cdn_bucket_name` (globally unique, optional)
  - `cdn_alt_domain` and `cdn_acm_cert_arn` (us-east-1) if using custom domain

- Optional – WAF
  - `create_waf_api` and/or `create_waf_cdn`

- Optional – Authorizer
  - `create_authorizer = true`
  - `authorizer_lambda_arn` (Lambda in same region/account)

Post-apply validation commands:
- `aws apigatewayv2 get-routes --api-id $(terraform output -raw api_id)`
- `curl -s $(terraform output -raw api_endpoint)/app-version/check`
- `kubectl run curl --image=curlimages/curl:8.5.0 -it --rm --restart=Never -- curl -s $(terraform output -raw api_endpoint)/app-version/check`

Destroy:
- Preview: `terraform plan -destroy -out=tfdestroy` then `terraform show -json tfdestroy | jq '.resource_changes | length'` to see the count.
- Execute: `terraform apply "tfdestroy"`.
- Notes:
  - NAT Gateways and EIPs delete last; expect several minutes.
  - RDS: `skip_final_snapshot = false` creates `final_snapshot_identifier`; deletion proceeds afterward.
  - Secrets Manager: `recovery_window_in_days = 7` delays hard delete but removes secret from active use.
  - CloudTrail/GuardDuty/Inspector: plan shows full teardown; no `prevent_destroy` protections are enabled.
  - If destroy is interrupted, re-run `terraform destroy -auto-approve` to finish cleanup.
