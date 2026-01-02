# AeroWise B2B Platform Infrastructure

Production-grade infrastructure as code for the AeroWise B2B mobile application platform on AWS.

## 📋 Overview

- **Architecture**: EKS (Kubernetes) + RDS PostgreSQL + API Gateway + CloudFront CDN
- **Region**: US East 1 (N. Virginia)
- **User Capacity**: 150 total users, 78-80 concurrent users
- **Monthly Cost**: $644 (optimized sizing)
- **Security**: Multi-AZ, KMS encryption, CloudTrail audit logging, WAF protection

## 🏗️ Infrastructure Components

### Compute
- **EKS Cluster** - Managed Kubernetes service
- **Worker Nodes** - 2× t3.small instances (1 vCPU, 2GB RAM each)
- **AWS Load Balancer Controller** - Helm-managed ALB provisioning
- **Auto Scaling** - Configured for 1-4 nodes (manual scaling via node group)

### Database
- **RDS PostgreSQL** - Multi-AZ deployment (primary + standby)
- **Instance**: db.t3.small (1 vCPU, 2GB RAM)
- **Storage**: 30GB gp2 SSD
- **Backup**: 7-day automated backups with point-in-time recovery
- **Encryption**: KMS CMK

### Networking
- **VPC** - 10.0.0.0/16 with multi-AZ subnets
- **NAT Gateways** - 2 gateways (one per AZ) for private egress
- **VPC Endpoints** - 10 interface endpoints (SSM, ECR, CloudWatch, Secrets Manager, etc.)
- **Application Load Balancer** - Internal ALB for microservice routing
- **API Gateway** - HTTP API with VPC Link to ALB

### Content Delivery & Security
- **CloudFront CDN** - Global distribution with Origin Access Control (OAC)
- **WAF** - Web Application Firewall for DDoS and attack protection
- **S3** - Static content origin with versioning and encryption

### Security Services
- **CloudTrail** - Audit logging (365-day retention) with KMS encryption
- **GuardDuty** - Threat detection and anomaly analysis
- **Inspector** - Vulnerability scanning (EC2, ECR, Lambda)
- **Security Hub** - CIS AWS Foundations Benchmark compliance
- **KMS** - Customer-managed encryption keys with auto-rotation

## 📁 Directory Structure

```
.
├── terraform/
│   ├── infra/                    # Main infrastructure stack
│   │   ├── main.tf              # Root configuration (module orchestration)
│   │   ├── variables.tf          # Input variables
│   │   ├── outputs.tf            # Stack outputs
│   │   ├── providers.tf          # AWS provider configuration
│   │   ├── terraform.tfvars      # Environment-specific variables
│   │   ├── terraform.tfvars.example
│   │   ├── lambda/
│   │   │   └── authorizer.py    # API Gateway authorizer function
│   │   └── scripts/
│   │       ├── DEPLOYMENT_GUIDE.md
│   │       ├── VERIFY_FLOW.md
│   │       └── verify-flow.sh
│   │
│   └── modules/                  # Reusable Terraform modules
│       ├── api-gateway/
│       ├── cdn/
│       ├── cloudtrail/
│       ├── db-secrets/
│       ├── eks/
│       ├── eks-oidc-provider/
│       ├── guardduty/
│       ├── inspector/
│       ├── kms-cmk/
│       ├── nat-egress-control/
│       ├── network/
│       ├── network-endpoints/
│       ├── network-policy/
│       ├── rds/
│       ├── security-hub/
│       └── waf_cdn/
│
├── kubernetes/                   # Kubernetes manifests
│   ├── internal-app-deployment.yaml
│   └── internal-app-targetgroupbinding.yaml
│
└── docs/                         # Documentation (in root for visibility)
    ├── AWS_PRICING_BREAKDOWN.md
    ├── INFRASTRUCTURE_COMPONENT_PRICING.md
    ├── PRICING_FOR_150_USERS.md
    ├── RDS_PRICING_VALIDATION.md
    ├── CUSTOMER_DEPLOYMENT_EMAIL.md
    ├── SECURITY_AUDIT_REPORT.md
    └── TERRAFORM_VALIDATION_REPORT.md
```

## 🚀 Quick Start

### Prerequisites
```bash
# Install required tools
brew install terraform aws-cli kubernetes-cli
aws configure  # Set up AWS credentials

# Verify versions
terraform version   # 1.x or later
aws --version      # 2.x or later
kubectl version    # 1.28+
```

### Deploy Infrastructure

**Phase 1: Create infrastructure**
```bash
cd terraform/infra

# Initialize Terraform
terraform init

# Validate configuration
terraform fmt -recursive && terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply (this will create 112+ resources)
TF_VAR_db_password="your-secure-password" terraform apply tfplan
# Deployment takes ~25-30 minutes
```

**Phase 2: Deploy Kubernetes application**
```bash
# Get EKS credentials
aws eks update-kubeconfig --region us-east-1 --name aerowise-t1-eks

# Deploy application
kubectl apply -f ../../kubernetes/internal-app-deployment.yaml

# Verify deployment
kubectl get pods -n mobileapp
kubectl get svc -n mobileapp
kubectl get ingress -n mobileapp
```

**Phase 3: Verify API Gateway integration**
```bash
# Get API endpoint from Terraform outputs
API_ENDPOINT=$(terraform output -raw api_endpoint)

# Test public route (no auth required)
curl -s "$API_ENDPOINT/app-version/check"

# Test from inside cluster (internal ALB)
kubectl run curl --image=curlimages/curl:8.5.0 -it --rm --restart=Never -- \
  curl -s "$API_ENDPOINT/app-version/check"
```

### Destroy Infrastructure

**⚠️ WARNING:** This will delete all resources including the database.

```bash
# Set variables for destroy
export TF_VAR_db_password="your-secure-password"

# Destroy
terraform destroy -auto-approve
```

## 📊 Pricing & Costs

**Monthly Cost Estimate (150 users, 78-80 concurrent): $644**

| Component | Cost | % |
|-----------|------|-----|
| RDS (db.t3.small Multi-AZ) | $293 | 45% |
| EKS Cluster + Nodes | $139 | 22% |
| Networking (NAT, VPC Link, Endpoints) | $157 | 24% |
| CloudFront CDN | $8.50 | 1% |
| Security Services | $8.13 | 1% |
| Other (API Gateway, Lambda, KMS, etc.) | $35 | 5% |

**Optimization Opportunities:**
- 1-Year Reserved Instances: -$158/month additional savings
- Auto-scaling with Spot instances: -$50/month (if workload allows)
- Regional WAF instead of CloudFront: -$5/month (trade-off: less DDoS protection)

See `PRICING_FOR_150_USERS.md` for detailed capacity analysis and scenarios.

## 🔒 Security Features

✅ **Encryption**
- Data in transit: TLS/SSL
- Data at rest: KMS CMK encryption (RDS, CloudTrail, Secrets Manager, EBS)

✅ **Network Isolation**
- Private RDS in isolated subnets (no direct internet access)
- EKS nodes in private subnets with NAT egress only
- API accessible via VPC Link (not directly from internet)
- EKS API endpoint: Public access (restrict CIDR in terraform.tfvars)

✅ **Audit & Compliance**
- CloudTrail: All API calls logged (365 days retention)
- GuardDuty: Real-time threat detection
- Inspector: Automated vulnerability scanning
- Security Hub: CIS AWS Foundations Benchmark v3.0.0

✅ **Deletion Protection**
- RDS: Deletion protection enabled
- CloudTrail: S3 bucket MFA delete (optional)

See `SECURITY_AUDIT_REPORT.md` for detailed security posture.

## 📈 Scaling

**Current Configuration: 150 users**
- RDS: db.t3.small (1 vCPU, 2GB)
- EKS: 2× t3.small nodes (1 vCPU, 2GB each)

**Scaling Path:**
| Users | DB | Nodes | Cost |
|-------|-----|-------|------|
| 150 | t3.small | 2× t3.small | $644 |
| 250-300 | t3.medium | 3× t3.small | $800 |
| 400-500 | t3.large | 4× t3.medium | $1,200 |

See `PRICING_FOR_150_USERS.md` for capacity verification and growth scenarios.

## 🔧 Configuration

### Main Variables (terraform/infra/terraform.tfvars)

```terraform
project_name = "aerowise-t1"
environment  = "prod"
aws_region   = "us-east-1"

# EKS Node Sizing (for 150 users)
desired_size = 2
min_size     = 1
max_size     = 4
instance_types = ["t3.small"]

# RDS (for 150 users)
# Update terraform/modules/rds/main.tf:
# db_instance_class = "db.t3.small"
# allocated_storage = 30

# Features
create_cdn = true
create_waf_cdn = true
create_aws_lb_controller_irsa = true

# EKS API Access (restrict in production)
eks_endpoint_public_access = true
eks_public_access_cidrs = ["YOUR_IP/32"]  # Replace with your office/VPN IP

# Ingress autodiscovery (enable after Phase 2)
enable_ingress_autodiscovery = false
```

### Database Configuration

Edit `terraform/modules/rds/main.tf` to adjust sizing:
```terraform
db_instance_class   = "db.t3.small"      # 1 vCPU, 2GB (for 150 users)
allocated_storage   = 30                 # GB
storage_type        = "gp2"              # General Purpose SSD
engine_version      = "17.6"             # PostgreSQL version
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **TERRAFORM_VALIDATION_REPORT.md** | Infrastructure validation (112 resources, security checks) |
| **SECURITY_AUDIT_REPORT.md** | Security posture, encryption, isolation, compliance |
| **PRICING_FOR_150_USERS.md** | Cost breakdown and capacity analysis for 150 users |
| **INFRASTRUCTURE_COMPONENT_PRICING.md** | Detailed per-component pricing (36 services) |
| **AWS_PRICING_BREAKDOWN.md** | Comprehensive service-by-service pricing |
| **RDS_PRICING_VALIDATION.md** | RDS cost validation (db.t3.small: $293/month) |
| **CUSTOMER_DEPLOYMENT_EMAIL.md** | Pre-deployment checklist and action items |

See `terraform/infra/scripts/` for deployment and verification guides.

## 🆘 Troubleshooting

### Common Issues

**1. EKS API Timeout**
```bash
# Disable ingress autodiscovery if cluster isn't ready
# In terraform.tfvars:
enable_ingress_autodiscovery = false

terraform plan  # Should work now
```

**2. RDS Deletion Protection Blocking Destroy**
```bash
# Temporarily disable in terraform
# Set: deletion_protection = false in terraform/modules/rds/main.tf
# Or use AWS CLI:
aws rds modify-db-instance \
  --db-instance-identifier aerowise-t1-postgres \
  --no-deletion-protection
```

**3. Calico Network Policy Timeout**
```bash
# Remove from state to speed up destroy
terraform state rm 'module.network_policy_mobile.helm_release.calico'
terraform destroy -auto-approve
```

**4. Lambda Function Validation**
```bash
# Ensure authorizer.py is present
ls -la terraform/infra/lambda/authorizer.py

# Re-zip if needed
cd terraform/infra
zip lambda/authorizer.zip lambda/authorizer.py
```

See `terraform/infra/scripts/TROUBLESHOOTING.md` for more help.

## 🔄 CI/CD Integration

This repository includes GitHub Actions workflows (in `.github/workflows/`) for:
- Terraform format & validation
- Plan review before apply
- Security scanning

Workflows are triggered on:
- Pull requests to `main`
- Commits to `main`
- Manual workflow dispatch

## 📞 Support

For questions or issues:
1. Check documentation in `DEPLOYMENT_GUIDE.md` and `VERIFY_FLOW.md`
2. Review security audit in `SECURITY_AUDIT_REPORT.md`
3. Consult pricing guides for cost questions
4. Review Terraform validation report for infrastructure issues

## 📝 License

Internal use only. AeroWise B2B Platform.

---

**Last Updated:** January 2, 2026  
**Maintained By:** Infrastructure Team  
**Status:** ✅ Production Ready (for 150 users, 78-80 concurrent)
