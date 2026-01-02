# Quick Deploy Guide - Multi-Account Support

## Deploy to Current Account (us-east-1)
```bash
cd terraform/infra
TF_VAR_db_password="password" terraform apply
```
✅ Already configured with existing backend

---

## Deploy to Same Account, Different Region
```bash
# Example: Deploy to eu-west-1
./setup-backend-dynamic.sh -p aerowise-t1 -r eu-west-1 -e prod

cd terraform/infra
terraform init \
  -backend-config="bucket=aerowise-t1-prod-terraform-state" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="dynamodb_table=aerowise-t1-prod-terraform-locks"

terraform apply -var="aws_region=eu-west-1"
```

---

## Deploy to Different AWS Account
```bash
# 1. Switch to target account
export AWS_PROFILE=production-account
aws sts get-caller-identity  # Verify correct account

# 2. Setup backend in new account
./setup-backend-dynamic.sh -p mycompany -r us-east-1 -e prod

# 3. Deploy infrastructure
cd terraform/infra
terraform init \
  -backend-config="bucket=mycompany-prod-terraform-state" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=mycompany-prod-terraform-locks"

terraform apply \
  -var="project_name=mycompany" \
  -var="aws_region=us-east-1"
```

---

## Deploy Multiple Environments
```bash
# Development
./setup-backend-dynamic.sh -p mycompany -r us-east-1 -e dev
terraform init -backend-config=backend-dev.tfvars
terraform apply -var-file=terraform-dev.tfvars

# Staging
./setup-backend-dynamic.sh -p mycompany -r us-east-1 -e staging
terraform init -backend-config=backend-staging.tfvars
terraform apply -var-file=terraform-staging.tfvars

# Production
./setup-backend-dynamic.sh -p mycompany -r us-east-1 -e prod
terraform init -backend-config=backend-prod.tfvars
terraform apply -var-file=terraform-prod.tfvars
```

---

## Validate Before Deploy
```bash
# Check multi-account compatibility
./validate-multi-account.sh

# Verify AWS credentials
aws sts get-caller-identity
aws configure get region

# Check service availability
aws eks describe-addon-versions --region YOUR_REGION
```

---

## Key Configuration Points

### terraform.tfvars
```hcl
project_name = "YOUR_PROJECT"     # Change this
aws_region   = "YOUR_REGION"      # Change this
db_username  = "postgres"
# db_password via TF_VAR_db_password environment variable
```

### Backend Setup Script
```bash
./setup-backend-dynamic.sh -p PROJECT -r REGION -e ENVIRONMENT
```

---

## Supported Regions (Examples)
- `us-east-1` - US East (N. Virginia) - Lowest cost
- `us-west-2` - US West (Oregon)
- `eu-west-1` - EU (Ireland)
- `eu-central-1` - EU (Frankfurt)
- `ap-south-1` - Asia Pacific (Mumbai)
- `ap-southeast-1` - Asia Pacific (Singapore)
- `ap-northeast-1` - Asia Pacific (Tokyo)

---

## Costs by Region (Approximate)
- us-east-1: $644/month (baseline)
- us-west-2: $676/month (+5%)
- eu-west-1: $708/month (+10%)
- ap-south-1: $740/month (+15%)

---

## Documentation
- **MULTI_ACCOUNT_READY.md** - Setup summary
- **MULTI_ACCOUNT_DEPLOYMENT.md** - Complete guide
- **S3_BACKEND_SETUP.md** - Backend details
