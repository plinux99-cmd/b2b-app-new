terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Update to support newer modules that require AWS provider v6+.
      version = ">= 6.0.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Many CloudFront / Global services (WAF CloudFront scope, ACM for CloudFront)
# must be operated in the us-east-1 region. Provide an aliased AWS provider
# so CDN/WAF CloudFront resources can be created in the correct region while
# keeping the primary provider pointed at the cluster region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}