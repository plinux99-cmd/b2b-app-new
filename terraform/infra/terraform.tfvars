project_name = "aerowise-t1"
environment  = "prod"
aws_region   = "us-east-1"
db_username  = "postgres"
# SECURITY: db_password removed from version control
# Set via environment variable: export TF_VAR_db_password="your-secure-password"
# Or pass during apply: terraform apply -var="db_password=your-secure-password"

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

# CDN: Upload index.html from local static folder
cdn_index_html_source_path = "static/index.html"

# Enable API Gateway integration and routes to the internal ALB
# IMPORTANT: Set alb_listener_arn to "" (empty) until the real mobileapp-alb Ingress exists.
# Once EKS cluster and mobileapp-alb Ingress are created and healthy, update this with the real listener ARN.
# ALB Listener ARN format: arn:aws:elasticloadbalancing:<region>:<account>:listener/app/<name>/<lb-id>/<listener-id>
alb_listener_arn = ""

# Ingress ALB autodiscovery - MUST be false on first apply (cluster doesn't exist yet)
# Set to true AFTER: (1) terraform apply completes, (2) kubectl apply -f kubernetes/internal-app-*.yaml runs
# Then run: terraform plan/apply again to auto-discover the mobileapp-alb Ingress
enable_ingress_autodiscovery = false

# Enable optional authorizer (set to true if Lambda authorizer exists)
create_authorizer     = true
authorizer_lambda_arn = "" # Lambda is created by this stack (aerowise-authorizer)

# Speed up destroy and avoid snapshot name conflicts
rds_skip_final_snapshot = true

# SECURITY: EKS API endpoint access control
# OPTION 1 (Recommended for production): Private-only access
# eks_endpoint_public_access = false
# eks_public_access_cidrs    = []
#
# OPTION 2 (Current - for development): Public access restricted to your IP
# Replace YOUR_IP with your actual public IP address from: curl -s ifconfig.me
eks_endpoint_public_access = true
eks_public_access_cidrs    = ["0.0.0.0/0"] # ⚠️ WARNING: Open to all IPs - RESTRICT THIS!
#
# OPTION 3 (Best for remote teams): Restrict to specific IPs/CIDR ranges
# eks_endpoint_public_access = true
# eks_public_access_cidrs    = ["YOUR_OFFICE_IP/32", "YOUR_VPN_IP/32"]
