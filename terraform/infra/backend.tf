# Terraform Backend Configuration - S3 with DynamoDB Locking
# This file enables remote state storage with state locking to prevent concurrent modifications

# MULTI-ACCOUNT / MULTI-REGION SUPPORT:
# This backend supports deployment across different AWS accounts and regions.
# 
# Setup Options:
# 
# OPTION 1 (Recommended): Partial Configuration via CLI
#   1. Run: ./setup-backend-dynamic.sh -p PROJECT_NAME -r REGION -e ENVIRONMENT
#   2. Then: terraform init -backend-config=backend.tfvars
#   
# OPTION 2: Direct CLI parameters
#   terraform init -backend-config="bucket=myproject-prod-terraform-state" \
#                  -backend-config="key=prod/terraform.tfstate" \
#                  -backend-config="region=us-east-1" \
#                  -backend-config="dynamodb_table=myproject-prod-terraform-locks" \
#                  -backend-config="encrypt=true"
#
# OPTION 3: Hardcode values below (least flexible)
#   Uncomment and update the backend block below with your specific values

# S3 Backend Configuration - Multi-Account Ready
terraform {
  backend "s3" {
    bucket         = "aerowise-t1-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aerowise-t1-terraform-locks"
    encrypt        = true
  }
}

# Full backend configuration (alternative - uncomment and customize)
# terraform {
#   backend "s3" {
#     bucket         = "YOUR-PROJECT-terraform-state"  # Change to your bucket name
#     key            = "prod/terraform.tfstate"         # State file path within bucket
#     region         = "us-east-1"                      # AWS region
#     dynamodb_table = "YOUR-PROJECT-terraform-locks"   # Change to your table name
#     encrypt        = true                             # Enable server-side encryption
#   }
# }

# Resource definitions for backend infrastructure (optional - run separately)
# These can be created via separate Terraform stack or AWS CLI

# Example: Create backend resources using AWS CLI
#
# aws s3api create-bucket \
#   --bucket aerowise-t1-terraform-state \
#   --region us-east-1 \
#   --create-bucket-configuration LocationConstraint=us-east-1
#
# aws s3api put-bucket-versioning \
#   --bucket aerowise-t1-terraform-state \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-server-side-encryption-configuration \
#   --bucket aerowise-t1-terraform-state \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws s3api put-bucket-public-access-block \
#   --bucket aerowise-t1-terraform-state \
#   --public-access-block-configuration \
#   "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
#
# aws dynamodb create-table \
#   --table-name aerowise-t1-terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
