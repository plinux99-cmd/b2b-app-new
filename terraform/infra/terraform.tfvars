project_name = "aerowise-t1"
environment  = "prod"
aws_region   = "us-east-1"
db_username  = "postgres"
db_password  = "ProdPass123Secure!"

# Single node group sized to two workers
desired_size = 2
min_size     = 1
max_size     = 4

# Enable NAT for private egress (required for EKS nodes/pods)
retain_nat_eips     = true
create_nat_gateways = true

# Enable WAFs and CDN (API Gateway v2 does not support WAFv2 regional; CDN WAF enabled)
create_waf_api = false
create_cdn     = true
create_waf_cdn = true

# Enable API Gateway integration and routes to the internal ALB
# IMPORTANT: Set alb_listener_arn to "" (empty) until the real mobileapp-alb Ingress exists.
# Once EKS cluster and mobileapp-alb Ingress are created and healthy, update this with the real listener ARN.
# ALB Listener ARN format: arn:aws:elasticloadbalancing:<region>:<account>:listener/app/<name>/<lb-id>/<listener-id>
alb_listener_arn = ""

# Enable optional authorizer (set to true if Lambda authorizer exists)
create_authorizer     = true
authorizer_lambda_arn = "" # Lambda is created by this stack (aerowise-authorizer)

# Ingress-based ALB auto-discovery: set false to avoid Kubernetes API calls when cluster is not ready
# Once EKS cluster and mobileapp-alb Ingress are created, set to true for auto-discovery
enable_ingress_autodiscovery = false

# Speed up destroy and avoid snapshot name conflicts
rds_skip_final_snapshot = true
