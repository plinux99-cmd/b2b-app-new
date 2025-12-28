data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Pull infra outputs (VPC, subnets, ALB listener) from ../infra
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../infra/terraform.tfstate"
  }
}

locals {
  vpc_id                = data.terraform_remote_state.infra.outputs.vpc_id
  private_app_subnets   = data.terraform_remote_state.infra.outputs.private_app_subnet_ids
  public_subnets        = data.terraform_remote_state.infra.outputs.public_subnet_ids
  alb_http_listener_arn = data.terraform_remote_state.infra.outputs.alb_http_listener_arn
}


# NOTE: API Gateway is created in the `infra` workspace. Use the remote
# state outputs to access the API id/endpoint/execution_arn. This keeps all
# infra provisioning in a single workspace (`terraform/infra`).

# Example usage of infra outputs (api id & execution arn) is below when needed.

# CloudFront CDN
module "cdn_static" {
  source       = "../modules/cdn"
  bucket_name  = "aerowise-edge-static-sample"
  name_suffix  = "sample"
  env          = "sample"
  alt_domain   = ""
  acm_cert_arn = null
  origin_path  = ""
}

# WAF modules (handles everything internally)
module "waf_api" {
  source      = "../modules/waf_api"
  name_suffix = "sample"
  # Use the API execution ARN from infra remote state (infra now owns the API)
  apigw_stage_arns = [data.terraform_remote_state.infra.outputs.api_execution_arn]
}


module "waf_cdn" {
  source         = "../modules/waf_cdn"
  name_suffix    = "sample"
  cloudfront_arn = module.cdn_static.cloudfront_distribution_id # Add this output to cdn module
  providers = {
    aws = aws.us_east_1
  }
}
