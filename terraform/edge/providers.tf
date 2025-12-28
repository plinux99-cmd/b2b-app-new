terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Provider for global CloudFront WAF resources (must be created in us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
