terraform {
  required_version = ">= 1.6.0"

  # Local State Backend (default)
  # State file: terraform.tfstate (checked into git for simplicity)
  # 
  # Note: For production with multiple users, consider S3 backend:
  # 1. Create S3 bucket with versioning enabled
  # 2. Add backend block and run: terraform init -migrate-state
  #
  # backend "s3" {
  #   bucket  = "your-project-terraform-state"
  #   key     = "prod/terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  #   # S3 now supports native state locking - no DynamoDB needed!
  # }

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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
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