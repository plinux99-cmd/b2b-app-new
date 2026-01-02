# Terraform Backend Configuration - S3 with DynamoDB Locking
# This file enables remote state storage with state locking to prevent concurrent modifications

# NOTE: Before applying this backend configuration:
# 1. Create S3 bucket and DynamoDB table (see setup-backend.sh script)
# 2. Update the bucket name and table name below if different from defaults
# 3. Run: terraform init (Terraform will prompt to migrate state to S3)

terraform {
  backend "s3" {
    # S3 Bucket Configuration
    bucket         = "aerowise-t1-terraform-state"  # Change to your bucket name
    key            = "prod/terraform.tfstate"        # State file path within bucket
    region         = "us-east-1"

    # DynamoDB Locking Configuration
    dynamodb_table = "aerowise-t1-terraform-locks"   # Change to your table name
    encrypt        = true                            # Enable server-side encryption

    # Skip credentials check during backend validation (use IAM instance roles)
    skip_credentials_validation = false
    skip_metadata_api_check     = false
  }
}

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
