variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "aerowise-t1"
}

variable "db_username" {
  # PROD: Customer to provide DB username (or manage via Secrets Manager).
  type      = string
  sensitive = true
}

variable "db_password" {
  # PROD: Customer to provide DB password (rotate via Secrets Manager/manager pipeline).
  type      = string
  sensitive = true
}
variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment prod"
}

# EKS Cluster Variables
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "aerowise-t1-eks"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "nodegroup_name" {
  description = "EKS node group name"
  type        = string
  default     = "main"
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "instance_types" {
  description = "Instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "common_tags" {
  type = map(string)
  default = {
    Project = "aerowise-t1"
  }
}

variable "existing_vpc_id" {
  description = "Optional: specify an existing VPC ID to use instead of creating a new VPC"
  type        = string
  default     = ""
}

variable "create_nat_gateways" {
  description = "Whether to create NAT gateways for private egress. Set false to proceed when EIPs cannot be managed (no egress from private subnets)."
  type        = bool
  default     = true
}

variable "retain_nat_eips" {
  description = "Retain NAT EIPs (prevent_destroy). Set false before destroy to allow EIP cleanup."
  type        = bool
  default     = true
}



variable "rds_skip_final_snapshot" {
  description = "Set true to skip final snapshot on RDS destroy (faster teardown, less safe). Keep false in prod."
  type        = bool
  default     = false
}

variable "eks_endpoint_public_access" {
  description = "Enable EKS public API endpoint access"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS public endpoint. Restrict to your office/VPN IP for security"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_ecr_public_endpoint" {
  description = "Whether to create the ECR public interface VPC endpoint (region-dependent)"
  type        = bool
  default     = false
}

variable "aws_lb_controller_role_arn" {
  description = "Optional: ARN of an existing IAM role for the AWS Load Balancer Controller. If provided, the IRSA role will not be created."
  type        = string
  default     = ""
}

variable "create_aws_lb_controller_irsa" {
  description = "Whether to create the IAM role for the load balancer controller via the IRSA module"
  type        = bool
  default     = true
}

variable "lb_controller_role_name" {
  description = <<-DESC
Optional: existing IAM role name for the AWS Load Balancer Controller (e.g. aws-load-balancer-controller).
If `create_aws_lb_controller_irsa = false`, you should provide either `aws_lb_controller_role_arn` or `lb_controller_role_name` so the ServiceAccount annotation can reference an existing role.
DESC
  type        = string
  default     = ""
}

# PROD/Cross-account: Provide an existing policy ARN if your account already has a consolidated
# AWS Load Balancer Controller policy. Leave empty to skip attaching extra policies.
variable "lb_controller_policy_arn" {
  description = "Optional: existing IAM policy ARN to attach to the LB Controller IRSA role (in target AWS account)."
  type        = string
  default     = ""
}

variable "create_api_gateway_integration" {
  description = "Deprecated: integration is now automatically created when alb_listener_arn is provided."
  type        = bool
  default     = false
}

variable "alb_listener_arn" {
  description = "Required: Listener ARN for the ALB (e.g., arn:aws:elasticloadbalancing:<region>:<account>:listener/app/<name>/<lb-id>/<listener-id>). Must be provided to create API Gateway VPC Link integration."
  type        = string
  default     = ""
}

variable "enable_ingress_autodiscovery" {
  description = "Whether to auto-discover the ALB from the Kubernetes Ingress. Set false when the EKS cluster/Ingress is not yet available to avoid Kubernetes provider calls during plan/refresh."
  type        = bool
  default     = true
}

# CDN & WAF toggles and inputs
variable "create_cdn" {
  description = "Whether to create a CloudFront + S3 CDN from the infra stack (opt-in)."
  type        = bool
  default     = false
}

variable "cdn_bucket_name" {
  # PROD: If customer requires a specific bucket name, set it here (must be globally unique).
  description = "Optional name for the CDN S3 bucket. If empty, a name derived from project_name will be used."
  type        = string
  default     = ""
}

variable "cdn_name_suffix" {
  description = "Suffix used for naming CDN resources"
  type        = string
  default     = "static"
}

variable "cdn_env" {
  description = "Environment tag for CDN resources"
  type        = string
  default     = "prod"
}

variable "cdn_alt_domain" {
  # PROD: If using custom domain for CDN, customer to provide DNS and ACM cert in us-east-1.
  description = "Optional alternate domain (CNAME) for the CloudFront distribution"
  type        = string
  default     = ""
}

variable "cdn_acm_cert_arn" {
  # PROD: ACM cert ARN in us-east-1 for CloudFront.
  description = "Optional ACM certificate ARN in us-east-1 to use for CloudFront. If not provided, the default CloudFront cert is used."
  type        = string
  default     = ""
}

variable "cdn_index_html_source_path" {
  description = "Optional: Local path to index.html file to upload to S3 (e.g., 'terraform/edge/static/index.html'). Leave empty to skip automatic upload."
  type        = string
  default     = ""
}

variable "create_waf_api" {
  description = "Whether to create a regional WAF for the API Gateway"
  type        = bool
  default     = false
}

variable "create_waf_cdn" {
  description = "Whether to create a CloudFront-scoped WAF in us-east-1 for the CDN"
  type        = bool
  default     = false
}

variable "waf_cdn_name_suffix" {
  description = "Name suffix for CDN WAF"
  type        = string
  default     = "cdn"
}

variable "create_authorizer" {
  # PROD: set true only if customer provides `authorizer_lambda_arn`.
  description = "Create Lambda authorizer and attach to protected routes"
  type        = bool
  default     = false
}

variable "authorizer_lambda_arn" {
  # PROD: customer-provided Lambda ARN in target account/region.
  description = "Lambda ARN for API authorizer"
  type        = string
  default     = ""
}

variable "authorizer_name" {
  description = "Name for API authorizer"
  type        = string
  default     = ""
}

variable "authorizer_identity_sources" {
  description = "Identity sources for authorizer"
  type        = list(string)
  default     = ["$request.header.authorization"]
}

variable "authorizer_payload_version" {
  description = "Payload version for authorizer"
  type        = string
  default     = "2.0"
}

variable "authorizer_result_ttl_in_seconds" {
  description = "TTL for authorizer cache"
  type        = number
  default     = 0
}

variable "create_custom_domain" {
  description = "Create custom domain and API mapping"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  # PROD: if customer needs custom API domain, provide name and ACM cert ARN.
  description = "Custom domain name for API"
  type        = string
  default     = ""
}

variable "custom_domain_acm_cert_arn" {
  # PROD: ACM cert ARN in the same region as the API (REGIONAL).
  description = "ACM cert ARN for custom domain"
  type        = string
  default     = ""
}

variable "custom_domain_base_path" {
  description = "Base path for API mapping (empty for root)"
  type        = string
  default     = ""
}

variable "custom_domain_endpoint_type" {
  description = "Endpoint type for custom domain"
  type        = string
  default     = "REGIONAL"
}

# Per-module Helm tuning for faster dev workflows (network_policy_mobile)
variable "network_policy_mobile_helm_wait" {
  description = "Pass-through to modules/network-policy.helm_wait. Default false to avoid long-running Calico Helm waits/timeouts during destroy; set true if you explicitly want Helm to wait."
  type        = bool
  default     = false
}

variable "network_policy_mobile_helm_timeout" {
  description = "Pass-through to modules/network-policy.helm_timeout (seconds)."
  type        = number
  default     = 300
}

variable "network_policy_mobile_helm_disable_hooks" {
  description = "Pass-through to modules/network-policy.helm_disable_hooks (default false). When true, Helm hooks will be disabled."
  type        = bool
  default     = false
}

# NiFi EC2 Instance Variables
variable "create_nifi_ec2" {
  description = "Create NiFi EC2 instance"
  type        = bool
  default     = true
}

variable "nifi_instance_type" {
  description = "EC2 instance type for NiFi"
  type        = string
  default     = "m5.2xlarge"
}

variable "nifi_storage_size" {
  description = "Size of NiFi EBS volume in GB"
  type        = number
  default     = 128
}

variable "nifi_ebs_volume_type" {
  description = "EBS volume type for NiFi (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "nifi_ebs_device_name" {
  description = "Device name for NiFi EBS volume"
  type        = string
  default     = "/dev/sdf"
}

variable "nifi_version" {
  description = "Apache NiFi version to install"
  type        = string
  default     = "1.25.0"
}

variable "nifi_ssh_allowed_cidr" {
  description = "CIDR blocks allowed for SSH access to NiFi instance"
  type        = list(string)
  default     = ["10.0.0.0/16"] # Restrict to VPC by default; override with your IP
}

variable "nifi_associate_public_ip" {
  description = "Associate public IP with NiFi instance"
  type        = bool
  default     = false
}

variable "nifi_ebs_encryption_enabled" {
  description = "Enable EBS encryption for NiFi volumes"
  type        = bool
  default     = true
}

variable "nifi_snapshot_retention_count" {
  description = "Number of EBS snapshots to retain for NiFi data volume"
  type        = number
  default     = 14
}

variable "cloudwatch_alarm_actions" {
  description = "SNS topic ARNs for CloudWatch alarm notifications"
  type        = list(string)
  default     = []
}

# NiFi Keycloak OIDC Authentication Variables
variable "nifi_enable_keycloak_auth" {
  description = "Enable Keycloak OIDC authentication for NiFi"
  type        = bool
  default     = false
}

variable "nifi_keycloak_url" {
  description = "Keycloak server URL (e.g., https://kc2.aerowiseplatform.com)"
  type        = string
  default     = ""
}

variable "nifi_keycloak_realm" {
  description = "Keycloak realm name for NiFi"
  type        = string
  default     = "aerowise"
}

variable "nifi_keycloak_client_id" {
  description = "Keycloak client ID for NiFi"
  type        = string
  default     = "nifi-client"
}

variable "nifi_keycloak_client_secret" {
  description = "Keycloak client secret for NiFi (sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "nifi_admin_identity" {
  description = "Initial NiFi admin user identity from Keycloak (email or username)"
  type        = string
  default     = "admin@aerowiseplatform.com"
}
