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
create_api_gateway_integration = true
alb_listener_arn               = "arn:aws:elasticloadbalancing:us-east-1:339712886638:listener/app/k8s-mobileap-internal-63a6eb7efe/a009f7db15c21764/d712add9ffb15817"
