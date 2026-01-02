module "network" {
  source              = "../modules/network"
  project_name        = var.project_name
  aws_region          = var.aws_region
  cluster_name        = "${var.project_name}-eks"
  existing_vpc_id     = var.existing_vpc_id
  create_nat_gateways = var.create_nat_gateways
  retain_nat_eips     = var.retain_nat_eips
}

# Data source for region (caller_identity is already in providers.tf)
data "aws_region" "current" {}

module "network_policy_mobile" {
  source         = "../modules/network-policy"
  app_namespace  = "mobileapp"
  app_port       = 80
  db_subnet_cidr = "10.0.10.0/16"

  # Helm tuning (optional, controlled via infra variables)
  helm_wait          = var.network_policy_mobile_helm_wait
  helm_timeout       = var.network_policy_mobile_helm_timeout
  helm_disable_hooks = var.network_policy_mobile_helm_disable_hooks

  depends_on = [module.eks]
}


## Remove standalone ALB – use the ALB created by AWS Load Balancer Controller via Ingress

module "eks" {
  source = "../modules/eks"

  project_name    = var.project_name
  environment     = "prod"
  region          = var.aws_region
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                 = module.network.vpc_id
  vpc_cidr               = "10.0.0.0/16"
  private_subnets        = module.network.private_subnets
  public_subnets         = module.network.public_subnets
  endpoint_public_access = var.eks_endpoint_public_access
  public_access_cidrs    = var.eks_public_access_cidrs

  nodegroup_name   = var.nodegroup_name
  desired_size     = var.desired_size
  min_size         = var.min_size
  max_size         = var.max_size
  instance_types   = var.instance_types
  nat_egress_sg_id = module.nat_egress_control.nategress_sg_id

  depends_on = [module.network, module.network_endpoints]
}

# Create OIDC provider for EKS cluster to enable IRSA
module "eks_oidc_provider" {
  source       = "../modules/eks-oidc-provider"
  cluster_name = module.eks.cluster_name
  project_name = var.project_name
  environment  = var.environment

  depends_on = [module.eks]
}

locals {
  eks_irsa_arns = []
}

locals {
  eks_oidc_provider = replace(
    module.eks_oidc_provider.oidc_issuer_url,
    "https://",
    ""
  )
}

// Use the well-maintained IAM module from the Terraform Registry to
// create an IRSA role and attach the Load Balancer Controller policy.
module "aws_lb_controller_irsa" {
  count  = var.create_aws_lb_controller_irsa ? 1 : 0
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"

  # keep a recognizable name similar to previous resource
  # use a shorter canonical name to avoid IAM name_prefix length limits
  name            = "aws-load-balancer-controller"
  use_name_prefix = false

  oidc_providers = {
    eks = {
      provider_arn               = module.eks_oidc_provider.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  attach_load_balancer_controller_policy = true
  # PROD/Cross-account: optionally attach an existing policy in the target account.
  policies = var.lb_controller_policy_arn != "" ? {
    existing_lb_policy = var.lb_controller_policy_arn
  } : {}

  # Note: policy creation behavior can be controlled with `create_policy` if needed.

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.eks_oidc_provider]
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.create_aws_lb_controller_irsa ? module.aws_lb_controller_irsa[0].arn : local.resolved_lb_controller_role_arn
    }
  }

  depends_on = [module.eks]
}

// If a role name is provided and no ARN is set, attempt to read the existing role
data "aws_iam_role" "existing_lb_controller" {
  count = var.lb_controller_role_name != "" && var.aws_lb_controller_role_arn == "" ? 1 : 0
  name  = var.lb_controller_role_name
}

locals {
  resolved_lb_controller_role_arn = var.aws_lb_controller_role_arn != "" ? var.aws_lb_controller_role_arn : (length(data.aws_iam_role.existing_lb_controller) > 0 ? data.aws_iam_role.existing_lb_controller[0].arn : "")
}
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}


resource "helm_release" "awsloadbalancercontroller" {
  name          = "aws-load-balancer-controller"
  repository    = "https://aws.github.io/eks-charts"
  chart         = "aws-load-balancer-controller"
  namespace     = "kube-system"
  version       = "1.7.2"
  timeout       = 1200
  wait          = true
  wait_for_jobs = true

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.aws_region
    vpcId       = module.network.vpc_id
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
    }
  })]

  depends_on = [
    kubernetes_service_account_v1.aws_load_balancer_controller,
    module.eks
  ]
}

# Discover the ALB created by the Ingress Controller from the Ingress status
data "kubernetes_ingress_v1" "internal_app" {
  count = var.enable_ingress_autodiscovery ? 1 : 0

  # Align with the actual ingress name so ALB auto-discovery works
  metadata {
    name      = "mobileapp-alb"
    namespace = "mobileapp"
  }
}

locals {
  ingress_alb_hostname = length(data.kubernetes_ingress_v1.internal_app) > 0 ? try(data.kubernetes_ingress_v1.internal_app[0].status[0].load_balancer[0].ingress[0].hostname, "") : ""
}

# Lambda authorizer for protected routes
data "archive_file" "authorizer_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/authorizer.py"
  output_path = "${path.module}/lambda/authorizer.zip"
}

data "aws_iam_policy_document" "authorizer_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_authorizer" {
  name               = "${var.project_name}-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.authorizer_assume.json

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "authorizer_basic" {
  role       = aws_iam_role.api_authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "api_authorizer" {
  function_name    = "${var.project_name}-authorizer"
  filename         = data.archive_file.authorizer_zip.output_path
  source_code_hash = data.archive_file.authorizer_zip.output_base64sha256
  handler          = "authorizer.handler"
  runtime          = "python3.11"
  role             = aws_iam_role.api_authorizer.arn
}

# Auto-discover ALB from Ingress hostname when available
data "aws_lb" "ingress_alb" {
  count = local.ingress_alb_hostname != "" ? 1 : 0
  # Extract ALB name from hostname: k8s-namespace-app-<hash>.elb.us-east-1.amazonaws.com
  name = try(regex("^(k8s-[a-z0-9-]+)", local.ingress_alb_hostname)[0], "")
}

# Get the HTTP listener (port 80) from the discovered ALB
data "aws_lb_listener" "ingress_http" {
  count             = length(data.aws_lb.ingress_alb) > 0 ? 1 : 0
  load_balancer_arn = data.aws_lb.ingress_alb[0].arn
  port              = 80
}

locals {
  # Auto-populate alb_listener_arn from discovered Ingress ALB, fallback to variable if set
  alb_listener_arn_from_ingress = try(data.aws_lb_listener.ingress_http[0].arn, "")
  effective_alb_listener_arn    = local.alb_listener_arn_from_ingress != "" ? local.alb_listener_arn_from_ingress : var.alb_listener_arn
}

# ---------- API GATEWAY + VPC LINK ----------
# Requires alb_listener_arn to be provided in terraform.tfvars.
# The ALB is created and managed externally (via Kubernetes Ingress Controller or manual creation).
module "api_gateway" {
  source = "../modules/api-gateway"

  project_name        = var.project_name
  environment         = var.environment
  vpc_link_subnet_ids = module.network.private_app_subnet_ids
  vpc_link_sg_id      = module.network.vpc_link_sg_id
  alb_listener_arn    = local.effective_alb_listener_arn

  # Create integration only if effective alb_listener_arn is available (auto-discovered or provided)
  create_integration = local.effective_alb_listener_arn != ""

  # API paths to create routes for (matching CDN paths)
  # These are public paths served through CDN that map to ALB
  api_paths = [
    "/app-version/check",
  ]

  # Authorizer is only created if both flag is true AND Lambda ARN is provided
  create_authorizer                = true
  authorizer_lambda_arn            = aws_lambda_function.api_authorizer.arn
  authorizer_name                  = "aerowise-authorizer"
  authorizer_identity_sources      = var.authorizer_identity_sources
  authorizer_payload_version       = var.authorizer_payload_version
  authorizer_result_ttl_in_seconds = var.authorizer_result_ttl_in_seconds

  create_custom_domain        = var.create_custom_domain
  custom_domain_name          = var.custom_domain_name
  custom_domain_acm_cert_arn  = var.custom_domain_acm_cert_arn
  custom_domain_base_path     = var.custom_domain_base_path
  custom_domain_endpoint_type = var.custom_domain_endpoint_type

  cors_allow_origins = ["*"]

  depends_on = [module.network, data.aws_lb_listener.ingress_http]
}

resource "aws_lambda_permission" "api_authorizer_invoke" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.api_id}/authorizers/*"
}

### Optional: CDN (CloudFront + S3) created in infra when `create_cdn = true`
module "cdn_static" {
  count                  = var.create_cdn ? 1 : 0
  source                 = "../modules/cdn"
  bucket_name            = var.cdn_bucket_name != "" ? var.cdn_bucket_name : "${var.project_name}-edge-static-${var.environment}"
  name_suffix            = var.cdn_name_suffix
  env                    = var.cdn_env
  alt_domain             = var.cdn_alt_domain
  acm_cert_arn           = var.cdn_acm_cert_arn != "" ? var.cdn_acm_cert_arn : null
  origin_path            = ""
  web_acl_id             = var.create_waf_cdn ? module.waf_cdn[0].web_acl_arn : ""
  index_html_source_path = var.cdn_index_html_source_path

  # Use CDN as a frontend for both static content (S3) and API Gateway.
  # Only the distribution created by this module is affected; the existing
  # non-Terraform CloudFront distribution remains untouched.
  api_origin_domain_name = replace(module.api_gateway.api_endpoint, "https://", "")
  api_paths = [
    "/app-version/check",
    "/assetservice*",
    "/paxservice*",
    "/flightservice*",
    "/notificationservice*",
    "/auth*",
  ]

}

### Optional: WAF for CloudFront (global/us-east-1 provider)
module "waf_cdn" {
  count       = var.create_waf_cdn && var.create_cdn ? 1 : 0
  source      = "../modules/waf_cdn"
  name_suffix = var.waf_cdn_name_suffix

  providers = {
    aws = aws.us_east_1
  }
}

# ---------- Secrets Manager ----------
module "db_secrets" {
  source      = "../modules/db-secrets"
  name        = "${var.project_name}-db-credentials"
  username    = var.db_username
  password    = var.db_password
  kms_key_arn = module.kms_cmk.key_arn

  tags = {
    Environment = "prod"
    Project     = var.project_name
    Name        = "${var.project_name}-db-credentials"
  }
}

# ---------- RDS PostgreSQL----------
module "rds_postgres" {
  source = "../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  db_name     = "aerowise"
  db_username = var.db_username
  db_password = var.db_password

  db_instance_class   = "db.t3.medium"
  allocated_storage   = 20
  storage_type        = "gp3"
  engine_version      = "17.6"
  skip_final_snapshot = var.rds_skip_final_snapshot

  vpc_id             = module.network.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = module.network.private_app_subnet_ids

  eks_node_sg_id = module.eks.node_security_group_id

  tags = merge(
    {
      Name        = "${var.project_name}-rds"
      Environment = var.environment
    }
  )
}



# CloudTrail 
module "cloudtrail" {
  source             = "../modules/cloudtrail"
  project_name       = var.project_name
  aws_region         = var.aws_region
  kms_key_arn        = module.kms_cmk.key_arn
  log_retention_days = 365
  tags = {
    Environment = "prod"
    Project     = var.project_name
  }
}

# GuardDuty
module "guardduty" {
  source = "../modules/guardduty"
}

module "inspector" {
  source = "../modules/inspector"

  account_ids = [data.aws_caller_identity.current.account_id]
  resource_types = [
    "EC2",   # eks nodes
    "ECR",   # Container registry
    "LAMBDA" # Authorizer Lambda
  ]
}

# Security Hub with CIS AWS Foundations Benchmark (v3.0.0 - Latest)
module "security_hub" {
  source = "../modules/security-hub"

  project_name         = var.project_name
  aws_region           = "us-east-1"
  environment          = "prod"
  auto_enable_controls = true

  tags = var.common_tags

  depends_on = [
    module.eks,
    module.cloudtrail,
    module.guardduty,
    module.inspector
  ]
}

# Production Hardening Modules
module "network_endpoints" {
  source                  = "../modules/network-endpoints"
  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  vpc_id                  = module.network.vpc_id
  vpc_cidr                = "10.0.0.0/16"
  vpc_link_sg_id          = module.network.vpc_link_sg_id
  private_subnet_ids      = module.network.private_app_subnet_ids
  private_subnet_cidrs    = module.network.private_app_subnet_cidrs
  private_route_table_ids = module.network.private_route_table_ids
  # The `network-endpoints` module intentionally does NOT consume
  # the EKS node security group (to avoid cross-module cycles). If
  # you need the node SG in a consumer, pass `module.eks.node_security_group_id`
  # explicitly to that module instead of here.
  create_ecr_public_endpoint = var.create_ecr_public_endpoint
  depends_on                 = [module.network]
}

# Explicit SG rule to allow EKS worker nodes to connect to the interface
# VPC endpoints on HTTPS port 443. This is separated from the endpoint
# module to avoid circular dependencies and to ensure correct ordering.
resource "aws_security_group_rule" "vpce_allow_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.network_endpoints.vpce_security_group_id
  source_security_group_id = module.eks.node_security_group_id
  description              = "Allow EKS worker nodes to reach VPC endpoints (HTTPS)"
}

module "kms_cmk" {
  source       = "../modules/kms-cmk"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  #  eks_cluster_role_arn = module.eks_cluster_role_arn
  depends_on = [module.eks]
}


# 3. NAT Egress Control
module "nat_egress_control" {
  source       = "../modules/nat-egress-control"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  #  nat_egress_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]  # RFC1918
  nat_egress_cidrs = ["0.0.0.0/0"]
  depends_on       = [module.network]
}




