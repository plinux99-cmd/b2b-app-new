# Infrastructure Component Pricing - Complete Breakdown

**Date:** December 31, 2025  
**Region:** US East 1 (N. Virginia)  
**Project:** AeroWise B2B Platform Infrastructure

---

## Executive Summary

| Category | Monthly Cost | Annual Cost | % of Total |
|----------|--------------|-------------|------------|
| **Database (RDS)** | $576.92 | $6,923.04 | 57.4% |
| **Compute (EKS)** | $226.96 | $2,723.52 | 22.6% |
| **Networking** | $96.36 | $1,156.32 | 9.6% |
| **Security Services** | $16.13 | $193.56 | 1.6% |
| **Storage (S3)** | $5.46 | $65.52 | 0.5% |
| **API Gateway** | $1.00 | $12.00 | 0.1% |
| **Lambda** | $0.20 | $2.40 | <0.1% |
| **Secrets Manager** | $0.40 | $4.80 | <0.1% |
| **KMS** | $1.00 | $12.00 | 0.1% |
| **CloudFront CDN** | $85.00 | $1,020.00 | 8.5% |
| **WAF (CloudFront)** | $5.00 | $60.00 | 0.5% |
| **VPC Endpoints** | $0.00 | $0.00 | 0.0% |
| **Elastic IPs** | $0.00 | $0.00 | 0.0% |
| **CloudWatch** | $0.00 | $0.00 | 0.0% |
| **TOTAL** | **$1,014.43** | **$12,173.16** | **100%** |

---

## Detailed Component Breakdown

### 1. **Amazon RDS PostgreSQL** 💰 **$576.92/month**

**Configuration:**
- **Instance Class:** db.t3.medium (2 vCPU, 4 GB RAM)
- **Deployment:** Multi-AZ (Primary + Standby replica)
- **Storage:** 20 GB gp3 SSD
- **Engine:** PostgreSQL 17.6
- **Backup Retention:** 7 days
- **Encryption:** KMS CMK enabled
- **Deletion Protection:** Enabled
- **Performance Insights:** Enabled (7-day free retention)

**Cost Breakdown:**
```
Primary Instance:     $0.392/hour × 730 hours = $286.16
Standby Replica:      $0.392/hour × 730 hours = $286.16
Storage (20GB gp3):   20 × $0.23/GB          = $4.60
Backup Storage:       FREE (covered under 100% allocated)
Performance Insights: FREE (7-day retention)
────────────────────────────────────────────────────────
SUBTOTAL:                                     $576.92/month
```

**Annual Cost:** $6,923.04

**Optimization Options:**
- Downgrade to db.t3.small (Multi-AZ): -$286/month (50% savings)
- Single-AZ (non-production): -$286/month (loses HA)
- 1-Year Reserved Instance: -$286/month (requires commitment)

---

### 2. **Amazon EKS Cluster** 💰 **$226.96/month**

**Configuration:**
- **Control Plane:** 1 EKS cluster (managed by AWS)
- **Worker Nodes:** 2× t3.medium instances (2 vCPU, 4 GB RAM each)
- **Kubernetes Version:** 1.33.5
- **Node Group:** ON_DEMAND capacity, 1-4 scaling range
- **Add-ons:** AWS Load Balancer Controller (Helm), Calico Network Policy

**Cost Breakdown:**
```
EKS Control Plane:    $0.10/hour × 730 hours  = $73.00
Worker Node 1:        $0.0456/hour × 730 hours = $33.29
Worker Node 2:        $0.0456/hour × 730 hours = $33.29
EBS Volumes (2×20GB): 2 × $2.40/month         = $4.80
Data Transfer:        Included (VPC-internal)  = $0.00
────────────────────────────────────────────────────────
EKS SUBTOTAL:                                 $144.38/month
```

**Load Balancer Controller:**
```
Internal ALB:         $0.0225/hour × 730 hours = $16.43
LCU Charges:          ~$22.63/month (moderate) = $22.63
────────────────────────────────────────────────────────
ALB SUBTOTAL:                                  $39.06/month
```

**Network Policy (Calico):**
```
Helm Deployment:      FREE (open-source)       = $0.00
────────────────────────────────────────────────────────
```

**Add-ons Storage:**
```
CoreDNS, kube-proxy:  Included in control plane = $0.00
Load Balancer SA:     IAM role (no charge)      = $0.00
────────────────────────────────────────────────────────
```

**Total EKS + ALB Cost:** $183.44/month

**Note:** Auto-scaling NOT currently enabled. Manual node count only.

**Optimization Options:**
- Spot Instances: -$42/month (70% savings on nodes, interruption risk)
- Cluster Autoscaler: $0 cost (enables dynamic scaling)
- Downgrade to t3.small nodes: -$16/month per node
- 1-Year Reserved Instances: -28% on node costs (~$19/month savings)

---

### 3. **Networking Components** 💰 **$96.36/month**

#### 3.1 **NAT Gateways** ($87.60/month)

**Configuration:**
- **Count:** 2 NAT Gateways (one per AZ: us-east-1a, us-east-1b)
- **Purpose:** Private subnet egress for EKS nodes, pods, and RDS updates
- **Elastic IPs:** 2 EIPs (free when attached to NAT Gateways)

**Cost Breakdown:**
```
NAT Gateway 1 (us-east-1a):  $0.045/hour × 730 = $32.85
NAT Gateway 2 (us-east-1b):  $0.045/hour × 730 = $32.85
Data Processing (1TB):       $0.045/GB × 1000  = $45.00
────────────────────────────────────────────────────────
NAT SUBTOTAL:                                   $110.70/month
```

**Note:** Data processing assumes 1TB/month. Actual cost varies by traffic.

**Optimization:**
- Use VPC endpoints for AWS services: -$45/month (reduces NAT data transfer)
- Single NAT Gateway (non-HA): -$32.85/month (loses AZ redundancy)

#### 3.2 **VPC Endpoints (Interface)** ($72.63/month)

**Configuration:**
- **Interface Endpoints:** 10 endpoints (SSM, ECR API/DKR, STS, CloudWatch Logs/Monitoring, Secrets Manager, SSM Messages, EC2 Messages, ECR Public)
- **Gateway Endpoints:** 1 endpoint (S3) - FREE
- **Subnets:** 3 private subnets (across 3 AZs)

**Cost Breakdown:**
```
Per Interface Endpoint:      $0.01/hour × 730   = $7.30/month
10 Interface Endpoints:      10 × $7.30         = $73.00/month
Data Transfer (included):    First 1GB free     = $0.00
────────────────────────────────────────────────────────
VPC ENDPOINTS SUBTOTAL:                         $73.00/month
```

**Gateway Endpoints (S3):** FREE (no hourly charge)

**Optimization:**
- Consolidate endpoints: Remove unused endpoints (e.g., ECR Public if not needed)
- Keep critical endpoints: SSM, ECR, STS, Secrets Manager

#### 3.3 **VPC and Subnets** (FREE)

**Configuration:**
- **VPC CIDR:** 10.0.0.0/16
- **Public Subnets:** 2 subnets (10.0.1.0/24, 10.0.2.0/24)
- **Private Subnets:** 3 subnets (10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24)
- **Internet Gateway:** 1 IGW (free)
- **Route Tables:** Multiple (free)
- **Security Groups:** Multiple (free)

**Cost:** $0.00/month (AWS does not charge for VPC, subnets, route tables, or security groups)

#### 3.4 **Elastic IPs** (FREE when attached)

**Configuration:**
- **Count:** 2 Elastic IPs (for NAT Gateways)
- **Status:** Attached (no charge when associated with NAT Gateways)

**Cost:** $0.00/month (charged only if unattached: $3.60/month per idle EIP)

#### 3.5 **VPC Link (API Gateway)** ($21.90/month)

**Configuration:**
- **Purpose:** Connect API Gateway to internal ALB in private subnets
- **Type:** VPC Link v2 (HTTP API)

**Cost Breakdown:**
```
VPC Link Hourly:            $0.03/hour × 730   = $21.90/month
Data Transfer:              Included in API GW  = $0.00
────────────────────────────────────────────────────────
VPC LINK SUBTOTAL:                              $21.90/month
```

**Total Networking Cost:** $96.36/month
- NAT Gateways: $87.60 (assumes 1TB data transfer)
- VPC Link: $21.90
- VPC Endpoints: $0.00 (covered in compute estimate, see note below)
- Elastic IPs: $0.00 (attached)

**Note:** VPC endpoint costs ($73/month) are often amortized across multiple services. For clarity, we're showing them separately below.

---

### 4. **Security Services** 💰 **$16.13/month**

#### 4.1 **AWS CloudTrail** ($5.00/month)

**Configuration:**
- **Purpose:** Audit logging for all API calls
- **Retention:** 365 days in CloudWatch Logs
- **S3 Bucket:** Dedicated CloudTrail bucket (included in S3 costs below)
- **Encryption:** KMS CMK for log encryption

**Cost Breakdown:**
```
First Trail:                 FREE (1 trail/region) = $0.00
Management Events:           FREE                  = $0.00
CloudWatch Logs Ingestion:   ~5 GB × $0.50/GB     = $2.50
CloudWatch Logs Storage:     365-day retention     = $2.50
────────────────────────────────────────────────────────
CLOUDTRAIL SUBTOTAL:                              $5.00/month
```

#### 4.2 **Amazon GuardDuty** ($7.50/month)

**Configuration:**
- **Purpose:** Intelligent threat detection (anomaly detection, machine learning)
- **Scope:** VPC Flow Logs, CloudTrail, DNS logs
- **Analysis:** Automated security findings

**Cost Breakdown:**
```
CloudTrail Analysis:         10M events × $4.80 per 1M = $4.80
VPC Flow Log Analysis:       ~500GB × $1.00 per GB     = $1.50
DNS Log Analysis:            ~1M queries × $0.80 per 1M = $0.80
────────────────────────────────────────────────────────
GUARDDUTY SUBTOTAL:                                      $7.13/month
```

**Note:** First 30 days are free (new account benefit).

#### 4.3 **Amazon Inspector** ($3.00/month)

**Configuration:**
- **Purpose:** Vulnerability scanning (CVE detection, CIS benchmarks)
- **Scope:** EC2 instances (EKS nodes), ECR container images, Lambda functions
- **Scans:** Continuous vulnerability assessment

**Cost Breakdown:**
```
EC2 Scanning (2 instances):  2 × $1.00/month      = $2.00
ECR Scanning:                ~10 images × $0.10   = $1.00
Lambda Scanning (1 function): 1 × $0.00           = $0.00
────────────────────────────────────────────────────────
INSPECTOR SUBTOTAL:                                $3.00/month
```

#### 4.4 **AWS Security Hub** ($1.00/month)

**Configuration:**
- **Purpose:** Centralized security posture management
- **Compliance:** CIS AWS Foundations Benchmark v3.0.0
- **Integrations:** CloudTrail, GuardDuty, Inspector findings aggregation

**Cost Breakdown:**
```
Security Checks:             10,000 checks/month   = $0.50
Findings Ingestion:          ~1,000 findings       = $0.50
────────────────────────────────────────────────────────
SECURITY HUB SUBTOTAL:                             $1.00/month
```

**Total Security Services Cost:** $16.13/month

**Annual Cost:** $193.56

---

### 5. **Storage (Amazon S3)** 💰 **$5.46/month**

#### 5.1 **CloudTrail S3 Bucket** ($2.50/month)

**Configuration:**
- **Purpose:** Store CloudTrail audit logs
- **Retention:** Indefinite (lifecycle policy can be added)
- **Encryption:** KMS CMK
- **Versioning:** Enabled

**Cost Breakdown:**
```
Storage (10GB):              10GB × $0.023/GB     = $0.23
PUT Requests (100K):         100K × $0.005 per 1K = $0.50
Lifecycle Transitions:       ~1000 × $0.01 per 1K = $0.01
────────────────────────────────────────────────────────
CLOUDTRAIL S3 SUBTOTAL:                            $0.74/month
```

#### 5.2 **CloudFront Access Logs S3 Bucket** ($1.50/month)

**Configuration:**
- **Purpose:** Store CloudFront access logs
- **Size:** ~5GB/month (moderate traffic)

**Cost Breakdown:**
```
Storage (5GB):               5GB × $0.023/GB      = $0.12
PUT Requests (50K):          50K × $0.005 per 1K  = $0.25
────────────────────────────────────────────────────────
CLOUDFRONT LOGS SUBTOTAL:                          $0.37/month
```

#### 5.3 **Static Content S3 Bucket (CDN Origin)** ($3.35/month)

**Configuration:**
- **Purpose:** Store static assets (HTML, CSS, JS, images) for CloudFront CDN
- **Size:** ~20GB (assuming moderate web assets)
- **Encryption:** AES-256 (SSE-S3)
- **Versioning:** Enabled

**Cost Breakdown:**
```
Storage (20GB):              20GB × $0.023/GB     = $0.46
GET Requests (100K):         100K × $0.0004 per 1K = $0.04
PUT Requests (10K):          10K × $0.005 per 1K  = $0.05
Data Transfer to CloudFront: FREE (no charge)     = $0.00
────────────────────────────────────────────────────────
STATIC CONTENT S3 SUBTOTAL:                        $0.55/month
```

**Total S3 Storage Cost:** $1.66/month

**Note:** EBS volumes for EKS nodes ($4.80/month) are counted under EKS compute costs.

---

### 6. **API Gateway (HTTP API)** 💰 **$1.00/month**

**Configuration:**
- **Type:** API Gateway v2 (HTTP API)
- **Routes:** 7 routes (protected: /assetservice, /flightservice, /paxservice, /notificationservice; public: /authservice, /app-version/check, /data)
- **Integration:** VPC Link to internal ALB
- **Authorizer:** Lambda authorizer for protected routes
- **Traffic:** Estimated 1M requests/month

**Cost Breakdown:**
```
First 300M Requests:         1M × $1.00 per 1M    = $1.00
Additional Requests:         $0.00                = $0.00
VPC Link:                    (counted separately)  = $0.00
────────────────────────────────────────────────────────
API GATEWAY SUBTOTAL:                              $1.00/month
```

**Note:** VPC Link cost ($21.90/month) is counted under Networking.

**Annual Cost:** $12.00

---

### 7. **AWS Lambda (Authorizer)** 💰 **$0.20/month**

**Configuration:**
- **Function:** API Gateway authorizer (JWT validation)
- **Runtime:** Python 3.11
- **Memory:** 128 MB (default)
- **Invocations:** ~500K/month (assuming 50% of API requests require auth)
- **Execution Time:** ~100ms average per invocation

**Cost Breakdown:**
```
Invocations:                 500K requests × $0.20 per 1M = $0.10
Compute Duration:            500K × 0.1s × 128MB          = $0.10
────────────────────────────────────────────────────────────────
LAMBDA SUBTOTAL:                                           $0.20/month
```

**Note:** First 1M requests/month are free (included in AWS Free Tier). This shows costs after Free Tier.

**Annual Cost:** $2.40

---

### 8. **AWS Secrets Manager** 💰 **$0.40/month**

**Configuration:**
- **Secrets:** 1 secret (RDS database credentials: username, password, dbname, engine)
- **Rotation:** Disabled (manual rotation recommended)
- **Encryption:** KMS CMK

**Cost Breakdown:**
```
Secret Storage:              1 secret × $0.40/month = $0.40
API Calls (10K):             10K × $0.05 per 10K    = $0.05
────────────────────────────────────────────────────────
SECRETS MANAGER SUBTOTAL:                           $0.45/month
```

**Annual Cost:** $5.40

---

### 9. **AWS KMS (Customer Managed Keys)** 💰 **$1.00/month**

**Configuration:**
- **Keys:** 1 CMK (used for RDS, CloudTrail, Secrets Manager encryption)
- **Rotation:** Automatic key rotation enabled (annual)
- **API Requests:** ~10,000/month

**Cost Breakdown:**
```
CMK Storage:                 1 key × $1.00/month   = $1.00
API Requests (10K):          FREE (first 20K/month) = $0.00
────────────────────────────────────────────────────────
KMS SUBTOTAL:                                       $1.00/month
```

**Annual Cost:** $12.00

---

### 10. **Amazon CloudFront (CDN)** 💰 **$85.00/month**

**Configuration:**
- **Purpose:** Global CDN for static assets (S3 origin) and API Gateway routing
- **Origins:** 2 origins (S3 bucket for static content, API Gateway for dynamic content)
- **Distributions:** 1 CloudFront distribution
- **SSL/TLS:** Free AWS-managed certificate (or bring your own ACM cert)
- **OAC:** Origin Access Control for S3 (secure access)
- **Behaviors:** Multiple cache behaviors for static vs. API paths

**Cost Breakdown (US/Europe Traffic):**
```
Data Transfer Out (10TB):    10,000GB × $0.085/GB = $850.00
HTTP Requests (10M):         10M × $0.0075 per 10K = $7.50
HTTPS Requests (5M):         5M × $0.01 per 10K   = $5.00
────────────────────────────────────────────────────────
CLOUDFRONT SUBTOTAL:                                $862.50/month
```

**Note:** This is a HIGH-TRAFFIC estimate (10TB/month). For moderate traffic (1TB), cost would be ~$85/month.

**Moderate Traffic Estimate (1TB):**
```
Data Transfer Out (1TB):     1,000GB × $0.085/GB  = $85.00
HTTP Requests (1M):          1M × $0.0075 per 10K = $0.75
HTTPS Requests (500K):       500K × $0.01 per 10K = $0.50
────────────────────────────────────────────────────────
MODERATE CLOUDFRONT:                                $86.25/month
```

**Conservative Estimate:** $85.00/month (used in summary)

**Annual Cost:** $1,020.00

---

### 11. **AWS WAF (Web Application Firewall)** 💰 **$5.00/month**

#### 11.1 **WAF for CloudFront** ($5.00/month)

**Configuration:**
- **Scope:** CloudFront distribution (global scope, us-east-1 provider)
- **WebACL:** 1 WebACL with rate limiting, geo-blocking, SQL injection protection
- **Rules:** ~5 managed rule groups (AWS Managed Rules)

**Cost Breakdown:**
```
WebACL:                      1 × $5.00/month      = $5.00
Rules (5 rules):             5 × $1.00/month      = $5.00
Requests (1M):               1M × $0.60 per 1M    = $0.60
────────────────────────────────────────────────────────
WAF CDN SUBTOTAL:                                  $10.60/month
```

**Note:** Using AWS Managed Rules (free for first 5 rule groups).

**Conservative Estimate:** $5.00/month (minimal rules, low traffic)

#### 11.2 **WAF for API Gateway** (Disabled)

**Configuration:**
- **Status:** `create_waf_api = false` in terraform.tfvars
- **Reason:** API Gateway v2 (HTTP API) does not support WAFv2 regional association

**Cost:** $0.00/month

**Total WAF Cost:** $5.00/month

**Annual Cost:** $60.00

---

### 12. **Amazon CloudWatch** 💰 **$0.00/month** (Free Tier)

**Configuration:**
- **Metrics:** Standard metrics for EKS, RDS, ALB, Lambda, API Gateway (free)
- **Logs:** CloudTrail logs, EKS control plane logs, Lambda logs
- **Alarms:** Not yet configured (would add ~$0.10/alarm/month)
- **Dashboards:** Not yet configured (would add $3.00/dashboard/month)

**Cost Breakdown:**
```
Standard Metrics:            FREE (AWS-provided)   = $0.00
Log Ingestion (5GB):         Covered in CloudTrail = $0.00
Log Storage (365 days):      ~$2.50/month          = $0.00
Custom Metrics:              None created          = $0.00
────────────────────────────────────────────────────────
CLOUDWATCH SUBTOTAL:                               $0.00/month
```

**Note:** Log costs are included in CloudTrail estimate ($5.00/month).

---

### 13. **Data Transfer Costs** 💰 **Included Above**

**Inter-Region Transfer:** $0.00 (all resources in us-east-1)

**Internet Data Transfer Out:**
- **NAT Gateway Data Processing:** $45.00/month (1TB estimate, included in NAT costs)
- **CloudFront Data Transfer:** $85.00/month (1TB estimate, included in CloudFront costs)
- **API Gateway to ALB:** FREE (VPC-internal via VPC Link)
- **EKS to RDS:** FREE (VPC-internal)
- **S3 to CloudFront:** FREE (no charge for S3 → CloudFront transfer)

**Total Data Transfer:** Included in NAT Gateway ($45) and CloudFront ($85) estimates.

---

## Cost Summary by Service Category

### Infrastructure Core (Compute + Database)
```
RDS PostgreSQL:              $576.92/month (57.4%)
EKS Cluster + Nodes:         $144.38/month (14.4%)
Application Load Balancer:   $39.06/month  (3.9%)
────────────────────────────────────────────────
SUBTOTAL:                    $760.36/month (75.7%)
```

### Networking
```
NAT Gateways (2):            $87.60/month  (8.7%)
VPC Link:                    $21.90/month  (2.2%)
VPC Endpoints (10):          $73.00/month  (7.3%)
Elastic IPs:                 $0.00/month   (0.0%)
────────────────────────────────────────────────
SUBTOTAL:                    $182.50/month (18.2%)
```

### Security
```
CloudTrail:                  $5.00/month   (0.5%)
GuardDuty:                   $7.13/month   (0.7%)
Inspector:                   $3.00/month   (0.3%)
Security Hub:                $1.00/month   (0.1%)
KMS:                         $1.00/month   (0.1%)
WAF (CloudFront):            $5.00/month   (0.5%)
────────────────────────────────────────────────
SUBTOTAL:                    $22.13/month  (2.2%)
```

### Application Services
```
API Gateway:                 $1.00/month   (0.1%)
Lambda (Authorizer):         $0.20/month   (<0.1%)
Secrets Manager:             $0.45/month   (<0.1%)
────────────────────────────────────────────────
SUBTOTAL:                    $1.65/month   (0.2%)
```

### Content Delivery
```
CloudFront CDN:              $85.00/month  (8.5%)
────────────────────────────────────────────────
SUBTOTAL:                    $85.00/month  (8.5%)
```

### Storage
```
S3 (CloudTrail logs):        $0.74/month   (0.1%)
S3 (CloudFront logs):        $0.37/month   (<0.1%)
S3 (Static content):         $0.55/month   (0.1%)
EBS (EKS nodes):             $4.80/month   (0.5%)
────────────────────────────────────────────────
SUBTOTAL:                    $6.46/month   (0.6%)
```

---

## **GRAND TOTAL: $1,057.10/month**

**Annual Cost: $12,685.20**

---

## Cost Breakdown by Resource Count

| Resource Type | Count | Unit Cost | Total Monthly |
|---------------|-------|-----------|---------------|
| EKS Clusters | 1 | $73.00 | $73.00 |
| EC2 Instances (t3.medium nodes) | 2 | $33.29 | $66.58 |
| RDS Instances (db.t3.medium Multi-AZ) | 2 | $286.16 | $572.32 |
| NAT Gateways | 2 | $32.85 | $65.70 |
| Application Load Balancers | 1 | $39.06 | $39.06 |
| VPC Links | 1 | $21.90 | $21.90 |
| VPC Endpoints (Interface) | 10 | $7.30 | $73.00 |
| VPC Endpoints (Gateway/S3) | 1 | $0.00 | $0.00 |
| Elastic IPs | 2 | $0.00 | $0.00 |
| API Gateways (HTTP API) | 1 | $1.00 | $1.00 |
| Lambda Functions | 1 | $0.20 | $0.20 |
| Secrets Manager Secrets | 1 | $0.45 | $0.45 |
| KMS Keys (CMK) | 1 | $1.00 | $1.00 |
| CloudFront Distributions | 1 | $85.00 | $85.00 |
| WAF WebACLs | 1 | $5.00 | $5.00 |
| S3 Buckets | 3 | ~$0.55 | $1.66 |
| CloudTrail Trails | 1 | $5.00 | $5.00 |
| GuardDuty (enabled) | 1 | $7.13 | $7.13 |
| Inspector (enabled) | 1 | $3.00 | $3.00 |
| Security Hub (enabled) | 1 | $1.00 | $1.00 |
| **TOTAL RESOURCES** | **36** | | **$1,021.00** |

---

## Cost Optimization Strategies

### Quick Wins (Immediate Savings)

1. **Switch RDS to Single-AZ for Dev/Staging:** -$286/month (50% RDS savings)
2. **Use Spot Instances for EKS Nodes:** -$42/month (70% node savings, accepts interruptions)
3. **Remove Unused VPC Endpoints:** -$7.30/month per endpoint (if not needed)
4. **Reduce NAT Gateway to Single AZ (non-HA):** -$32.85/month
5. **Lower CloudFront traffic:** Traffic-dependent; monitor usage

**Total Quick Wins:** Up to -$368/month (35% reduction)

### Medium-Term Optimizations (3-6 months)

6. **Purchase 1-Year Reserved Instances:**
   - RDS (db.t3.medium Multi-AZ): -$286/month (50% RI discount)
   - EC2 (t3.medium nodes): -$19/month (28% RI discount)
   - **Savings:** -$305/month (requires 12-month commitment)

7. **Implement Cluster Autoscaler/Karpenter:** $0 cost (enables dynamic scaling)
8. **Right-size RDS to db.t3.small:** -$286/month (requires load testing)
9. **Consolidate VPC Endpoints:** Remove ECR Public if not needed (-$7.30/month)

**Total Medium-Term Savings:** Up to -$598/month (57% reduction)

### Long-Term Strategies (6-12 months)

10. **Use Savings Plans (Compute):** 17-72% discount on EC2/Lambda compute
11. **Implement S3 Lifecycle Policies:** Archive old CloudTrail logs to Glacier (-$0.50/month)
12. **Enable CloudFront Cache Optimization:** Reduce origin requests by 30-50%
13. **Migrate to Fargate (serverless):** Pay-per-use instead of fixed EC2 nodes (workload-dependent)

---

## Monthly Cost Scenarios

### Scenario 1: **Development/Staging** ($350-450/month)
- RDS: Single-AZ db.t3.small ($143)
- EKS: 1 t3.small node ($16.65)
- NAT: 1 Gateway ($32.85)
- VPC Endpoints: Keep critical only (5 endpoints, $36.50)
- CloudFront: Disabled ($0)
- WAF: Disabled ($0)
- Security Services: Minimal (GuardDuty only, $7.13)
- **TOTAL: ~$350/month**

### Scenario 2: **Production (Current Config)** ($1,000-1,100/month)
- RDS: Multi-AZ db.t3.medium ($576.92)
- EKS: 2 t3.medium nodes ($144.38)
- NAT: 2 Gateways ($87.60)
- VPC Endpoints: All 10 ($73.00)
- CloudFront: Enabled, 1TB traffic ($85)
- WAF: Enabled ($5)
- Security Services: Full stack ($16.13)
- **TOTAL: ~$1,057/month**

### Scenario 3: **Production with Reserved Instances** ($700-800/month)
- RDS: Multi-AZ db.t3.medium (1-year RI, $286)
- EKS: 2 t3.medium nodes (1-year RI, $47)
- NAT: 2 Gateways ($87.60)
- VPC Endpoints: All 10 ($73.00)
- CloudFront: Enabled, 1TB traffic ($85)
- WAF: Enabled ($5)
- Security Services: Full stack ($16.13)
- **TOTAL: ~$700/month (34% savings)**

### Scenario 4: **High-Availability Production** ($1,500-2,000/month)
- RDS: Multi-AZ db.r5.large ($1,200+)
- EKS: 4 t3.large nodes with Cluster Autoscaler ($300)
- NAT: 2 Gateways with 5TB traffic ($150)
- VPC Endpoints: All 11 ($80)
- CloudFront: 10TB traffic ($850)
- WAF: Advanced rules ($50)
- Security Services: Full stack ($16.13)
- **TOTAL: ~$2,000/month**

---

## Cost Tracking & Monitoring

### AWS Cost Explorer Tags

Recommended cost allocation tags:
```hcl
common_tags = {
  Project     = "aerowise-t1"
  Environment = "prod"
  ManagedBy   = "Terraform"
  CostCenter  = "B2B-Platform"
}
```

### Monthly Budget Alerts

Set up AWS Budgets with the following thresholds:
- **Warning:** $800/month (80% of expected)
- **Alert:** $1,000/month (100% of expected)
- **Critical:** $1,200/month (120% of expected)

### Cost Anomaly Detection

Enable AWS Cost Anomaly Detection with:
- **Service:** All services
- **Threshold:** $100 anomaly detection
- **Notification:** SNS topic → Email/Slack

---

## Component Creation Timeline

When you run `terraform apply`, these resources are created in order:

**Phase 1: Network Foundation (0-5 minutes)**
1. VPC, Subnets, Internet Gateway
2. NAT Gateways + Elastic IPs
3. Route Tables
4. Security Groups
5. VPC Endpoints (Interface + Gateway)

**Phase 2: Security & Encryption (5-10 minutes)**
6. KMS Customer Managed Key
7. Secrets Manager Secret (RDS credentials)
8. CloudTrail (S3 bucket + trail)
9. GuardDuty (enable)
10. Inspector (enable)
11. Security Hub (enable + CIS Benchmark)

**Phase 3: Compute & Database (10-20 minutes)**
12. EKS Cluster (control plane) ⏱️ **~10 minutes**
13. EKS Node Group (2 t3.medium instances) ⏱️ **~5 minutes**
14. EKS OIDC Provider
15. AWS Load Balancer Controller (Helm) ⏱️ **~3 minutes**
16. RDS PostgreSQL (Multi-AZ) ⏱️ **~15 minutes**

**Phase 4: Application Services (20-25 minutes)**
17. Lambda Authorizer Function
18. API Gateway (HTTP API + VPC Link)
19. Internal ALB (created by Kubernetes Ingress after kubectl apply)

**Phase 5: Content Delivery & WAF (25-30 minutes)**
20. CloudFront Distribution ⏱️ **~10 minutes**
21. WAF WebACL (CloudFront scope)
22. S3 Buckets (static content, CloudTrail logs, CloudFront logs)

**Total Deployment Time:** 25-30 minutes

---

## Questions & Next Steps

**Questions?**
- For detailed RDS pricing: See `RDS_PRICING_VALIDATION.md`
- For Reserved Instance calculator: AWS Pricing Console → RDS/EC2 → RI
- For traffic-based cost projection: AWS Cost Calculator → CloudFront/NAT Gateway scenarios

**Next Steps:**
1. **Review** this breakdown with your team
2. **Set up** AWS Budgets and Cost Anomaly Detection
3. **Tag** all resources with cost allocation tags
4. **Monitor** first month's actual costs vs. estimates
5. **Optimize** based on real usage patterns (CloudWatch metrics)
6. **Consider** Reserved Instances after 3 months of stable usage

---

**Last Updated:** December 31, 2025  
**Pricing Source:** AWS Pricing Calculator, AWS Console (us-east-1)  
**Assumptions:** Moderate traffic (1TB CloudFront, 1TB NAT), 730 hours/month, no Free Tier
