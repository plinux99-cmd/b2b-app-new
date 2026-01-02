#!/bin/bash
# Dynamic Terraform Backend Setup
# Creates S3 bucket and DynamoDB table for remote state with locking
# Works across any AWS account and region

set -e  # Exit on error

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -p PROJECT_NAME -r REGION [-e ENVIRONMENT]

Creates S3 bucket and DynamoDB table for Terraform remote state.

Required Arguments:
  -p PROJECT_NAME    Project name prefix (e.g., mycompany, aerowise)
  -r REGION          AWS region (e.g., us-east-1, eu-west-1, ap-south-1)

Optional Arguments:
  -e ENVIRONMENT     Environment name (default: prod)
  -h                 Show this help message

Examples:
  # US East 1 deployment
  $0 -p mycompany -r us-east-1

  # EU West 1 deployment  
  $0 -p mycompany -r eu-west-1 -e dev

  # Asia Pacific deployment
  $0 -p mycompany -r ap-south-1 -e staging

This will create:
  - S3 Bucket: {PROJECT_NAME}-{ENVIRONMENT}-terraform-state
  - DynamoDB Table: {PROJECT_NAME}-{ENVIRONMENT}-terraform-locks
EOF
    exit 1
}

# Parse command line arguments
PROJECT_NAME=""
REGION=""
ENVIRONMENT="prod"

while getopts "p:r:e:h" opt; do
    case $opt in
        p) PROJECT_NAME="$OPTARG" ;;
        r) REGION="$OPTARG" ;;
        e) ENVIRONMENT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [ -z "$PROJECT_NAME" ] || [ -z "$REGION" ]; then
    echo "❌ Error: PROJECT_NAME and REGION are required"
    usage
fi

# Configuration
BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-terraform-state"
TABLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-terraform-locks"

echo "======================================"
echo "Terraform Backend Setup"
echo "======================================"
echo "Project:     $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Bucket:      $BUCKET_NAME"
echo "Table:       $TABLE_NAME"
echo "Region:      $REGION"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first:"
    echo "   macOS:   brew install awscli"
    echo "   Linux:   pip install awscli"
    echo "   Windows: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
echo "🔍 Checking AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --region "$REGION" --query 'Account' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ AWS credentials not configured or invalid"
    echo "   Run: aws configure"
    exit 1
fi
echo "✅ AWS Account: $ACCOUNT_ID"
echo ""

# Create S3 bucket
echo "📦 Creating S3 bucket for state storage..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo "⚠️  Bucket already exists: $BUCKET_NAME"
else
    # Special handling for us-east-1 (doesn't need LocationConstraint)
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "✅ Bucket created: $BUCKET_NAME"
fi

# Enable versioning
echo "🔄 Enabling S3 versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled
echo "✅ Versioning enabled"

# Enable encryption
echo "🔐 Enabling S3 encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
echo "✅ Encryption enabled"

# Block public access
echo "🔒 Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "✅ Public access blocked"

# Add bucket tags
echo "🏷️  Adding tags..."
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --tagging "TagSet=[{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=Purpose,Value=TerraformState},{Key=ManagedBy,Value=Terraform}]"
echo "✅ Tags added"
echo ""

# Create DynamoDB table
echo "🔐 Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "⚠️  Table already exists: $TABLE_NAME"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --region "$REGION" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" Key=Purpose,Value=TerraformStateLocking Key=ManagedBy,Value=Terraform
    
    echo "⏳ Waiting for table to be created..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
    echo "✅ Table created: $TABLE_NAME"
fi

# Enable TTL on DynamoDB table
echo "⏰ Enabling TTL on DynamoDB table..."
aws dynamodb update-time-to-live \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --time-to-live-specification "Enabled=true,AttributeName=Expires" > /dev/null 2>&1 || true
echo ""

echo "======================================"
echo "✅ Backend Setup Complete!"
echo "======================================"
echo ""
echo "Backend Configuration:"
cat << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "${ENVIRONMENT}/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true
  }
}
EOF
echo ""
echo "Next Steps:"
echo "1. Update terraform/infra/backend.tf with above configuration"
echo "   OR use backend config file:"
echo "   terraform init -backend-config=\"bucket=$BUCKET_NAME\" \\"
echo "                  -backend-config=\"key=${ENVIRONMENT}/terraform.tfstate\" \\"
echo "                  -backend-config=\"region=$REGION\" \\"
echo "                  -backend-config=\"dynamodb_table=$TABLE_NAME\" \\"
echo "                  -backend-config=\"encrypt=true\""
echo ""
echo "2. Run: cd terraform/infra"
echo "3. Run: terraform init"
echo "4. Answer 'yes' to migrate state to S3"
echo ""
echo "Verify backend:"
echo "  aws s3 ls $BUCKET_NAME --recursive --region $REGION"
echo "  aws dynamodb scan --table-name $TABLE_NAME --region $REGION"
