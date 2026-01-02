# AeroWise Infrastructure - Monthly AWS Cost Breakdown
**Region:** us-east-1 (N. Virginia)  
**Date:** December 31, 2025  
**Based on:** Current Infrastructure as Code Configuration

---

## 📊 Executive Summary

| Category | Monthly Cost |
|----------|--------------|
| **Compute (EKS)** | $87.12 |
| **Database (RDS PostgreSQL)** | $120.96 |
| **Networking** | $67.50 |
| **CDN & WAF** | $35.00-100.00 |
| **Security & Monitoring** | $15.00-50.00 |
| **Data Transfer** | ~$10.00 |
| **TOTAL (Base Estimate)** | **$335.58 - $470.58** |

---

## 💻 1. Compute - Amazon EKS

### EKS Control Plane
```
EKS Cluster: $0.10/hour × 730 hours/month = $73.00
```
**Note:** EKS cluster cost is fixed regardless of node count.

### EKS Worker Nodes
**Configuration:**
- Instance Type: `t3.medium`
- Instance Count: 2 (desired_size)
- On-Demand (no spot instances)

**Pricing:**
- t3.medium on-demand: $0.0416/hour
- Per instance monthly: $0.0416 × 730 hours = $30.37
- Total (2 nodes): $30.37 × 2 = **$60.74**

### EKS Add-ons
```
CoreDNS:   $0.025/month
VPC CNI:   $0.00 (no charge)
EBS CSI:   $0.00 (no charge)
```

### EKS Subtotal
```
EKS Control Plane:      $73.00
Worker Nodes (2x):      $60.74
EKS Add-ons:            $0.25
─────────────────────────────
Total Compute:          $134.00 (High estimate due to t3.medium)
```

**Cost Optimization Opportunities:**
- Downsize to `t3.small` ($0.0208/hour) = saves ~$15/month per node
- Use Spot Instances (up to 70% savings) = ~$18-21/month for 2 nodes
- Implement Cluster Autoscaler to scale down when not needed

---

## 🗄️ 2. Database - Amazon RDS PostgreSQL

### RDS Instance
**Configuration:**
- Instance Class: `db.t3.medium`
- Storage: 20 GB (gp3)
- Multi-AZ: **Enabled** (creates standby replica for HA)
- Storage Type: gp3
- Backup Retention: 7 days

**Pricing Breakdown:**

| Component | Cost |
|-----------|------|
| **db.t3.medium (primary)** | $0.1184/hour × 730 hrs | $86.42 |
| **Multi-AZ Standby Replica** | $0.1184/hour × 730 hrs | $86.42 |
| **Storage (20 GB gp3)** | 20 × $0.115/month | $2.30 |
| **Backup Storage (7-day retention)** | ~20 GB × $0.095/month | $1.90 |
| **Data Transfer (inter-AZ)** | Multi-AZ replication | ~$10-15 |
| **Performance Insights** | Enabled by default | Free (with Multi-AZ) |

### RDS Subtotal
```
Primary Instance:       $86.42
Standby Replica:        $86.42
Storage:                $2.30
Backup Storage:         $1.90
Multi-AZ Replication:   $12.50 (avg)
─────────────────────────────
Total Database:         $189.54
```

**Alternative Scenarios:**

| Scenario | Monthly Cost | Notes |
|----------|--------------|-------|
| Single AZ (no Multi-AZ) | $88.72 | No HA, not recommended for prod |
| db.t3.small (Multi-AZ) | $124.98 | Better for low traffic apps |
| db.t3.micro (Multi-AZ) | $95.24 | Free tier alternative if <750GB |
| **Current (db.t3.medium Multi-AZ)** | **$189.54** | Production-ready HA setup |

---

## 🌐 3. Networking

### NAT Gateway
```
NAT Gateway Data Processing: $0.045/GB
Estimated Data Transfer: 50-100 GB/month (typical)
Cost per NAT Gateway: $2.25 - $4.50

You have: 2 NAT Gateways (one per AZ for HA)
Total NAT GW costs: $4.50 - $9.00
```

### Application Load Balancer (ALB)
```
ALB Hourly: $0.0225/hour × 730 hours
ALB Data Processing: $0.006/GB (estimated 10 GB/month)

ALB Cost: $16.43 + $0.06 = $16.49
```

### API Gateway (HTTP API v2)
```
API Calls: $0.90 per million requests
Estimated traffic: 1 million requests/month = $0.90

Cache charges: $0.02/GB (minimal with 1GB cache)
─────────────────────────────
API Gateway: $0.90
```

### VPC & VPC Endpoints
```
VPC: Free
VPC Endpoints (11 endpoints): ~$0.40 per endpoint-month
Total VPC Endpoints: 11 × $0.40 = $4.40

Data processed through endpoints: $0.01/GB (minimal)
─────────────────────────────
VPC Endpoints: $4.40
```

### EIP (Elastic IPs)
```
EIP Address (when associated): Free
EIP Address (when not associated): $0.005/hour
Status: Associated to NAT Gateways = Free
─────────────────────────────
EIP Cost: $0.00
```

### Networking Subtotal
```
NAT Gateways:           $6.75
ALB:                    $16.49
API Gateway:            $0.90
VPC Endpoints:          $4.40
EIPs:                   $0.00
─────────────────────────────
Total Networking:       $28.54
```

---

## 📡 4. Content Delivery & WAF

### CloudFront CDN
**Configuration:**
- Enabled: Yes
- Origin: S3 (static site)
- WAF: Enabled
- Caching: Default (1 day TTL)

**Pricing Depends on Data Transfer:**

| Traffic Volume | Monthly Cost |
|---|---|
| 10 GB/month | $0.85 |
| 50 GB/month | $4.25 |
| 100 GB/month | $8.50 |
| 500 GB/month | $42.50 |
| 1 TB/month | $85.00 |

**Estimated baseline (minimal traffic):** $10-20/month

### AWS WAF (CloudFront-scope)
```
Web ACL: $5.00/month (fixed)
Rules: Standard rules included
Requests: $0.60 per million requests (minimal for internal use)
─────────────────────────────
WAF Cost: $5.00-10.00
```

### S3 Storage (CloudFront + CloudTrail logs)
```
CloudFront origin (static site): ~5 GB × $0.023/GB = $0.12
CloudTrail logs: ~50 GB/month × $0.023/GB = $1.15
Backup snapshots: Minimal
─────────────────────────────
S3 Cost: ~$1.27 + request charges (~$0.10)
```

### CDN & WAF Subtotal
```
CloudFront:             $10.00 (est. low traffic)
WAF:                    $5.00
S3 Storage:             $1.37
─────────────────────────────
Total CDN & WAF:        $16.37
```

**Varies based on data transfer:** Could be $16-100/month depending on traffic volume.

---

## 🔒 5. Security & Monitoring

### CloudTrail
```
API Calls Logged: First 100,000 = Free (included)
Additional: $2.00 per 100,000 events
Typical production: ~50,000 events/month = Free

CloudTrail Storage (S3): Covered in S3 costs above
CloudWatch Logs: ~$0.50/GB ingested, ~$0.03/GB stored
Estimated: $1.00/month
─────────────────────────────
CloudTrail: ~$1.00
```

### GuardDuty
```
Account activation: Free
EC2/ECS scanning: $0.004 per instance-hour
Estimated (2 EKS nodes): $0.004 × 2 × 730 = $5.84
Finding ingestion: Free (EBS snapshots, RDS logs included)
─────────────────────────────
GuardDuty: ~$5.84
```

### Inspector
```
Scanning scope: EC2 + ECR + Lambda
EC2 scanning (2 nodes): Free for t3 instances (burstable)
ECR scanning: $0.009 per image scan
Lambda scanning: Free for v2
─────────────────────────────
Inspector: ~$0.50 (minimal)
```

### Security Hub
```
Monthly subscription: Free (CIS AWS Foundations Benchmark)
Custom insights/findings: Included
─────────────────────────────
Security Hub: Free
```

### CloudWatch
```
Logs ingestion: ~$0.50/GB (EKS logs, RDS logs, etc.)
Estimated: 5 GB/month = $2.50

Log retention: 365 days (configured)
Alarms: 5 free per account, then $0.10 each
Dashboard: Free (3 dashboards included)
─────────────────────────────
CloudWatch: ~$3.00
```

### KMS (Key Management Service)
```
Customer-managed CMK: $1.00/month
Key rotation (auto): Included
API requests: $0.03 per 10,000 requests
Estimated requests: 1 million/month = $3.00
─────────────────────────────
KMS: ~$4.00
```

### Secrets Manager
```
Secret storage: $0.40/month per secret
You have: 1 RDS secret + config secrets = 2 secrets
Secret rotation API calls: $0.05 per 10,000 API calls
─────────────────────────────
Secrets Manager: ~$0.80
```

### Security & Monitoring Subtotal
```
CloudTrail:             $1.00
GuardDuty:              $5.84
Inspector:              $0.50
Security Hub:           $0.00
CloudWatch:             $3.00
KMS:                    $4.00
Secrets Manager:        $0.80
─────────────────────────────
Total Security:         $15.14
```

---

## 📤 6. Data Transfer & Miscellaneous

### Data Transfer Costs
```
Data OUT (internet): $0.09/GB
Estimated outbound traffic: 50-100 GB/month
Cost: $4.50 - $9.00

Data between AZs: $0.01/GB (RDS Multi-AZ replication)
Estimated: 20-50 GB/month = $0.20 - $0.50

Regional data transfer: Included in NAT costs
```

### Miscellaneous
```
Route 53 (DNS, if used): $0.50/hosted zone/month
CloudFormation: Free (we use Terraform)
Elastic Container Registry (ECR): $0.10/GB storage/month
Lambda (API authorizer): ~1M requests/month = Free tier
```

### Data Transfer Subtotal
```
Internet Data Transfer:    $6.75
Inter-AZ Transfer:         $0.35
Route 53:                  $0.50
ECR Storage:               ~$0.20
─────────────────────────────
Total Data Transfer:       $7.80
```

---

## 💰 Total Monthly Cost Summary

| Service | Cost Range | Notes |
|---------|-----------|-------|
| EKS Compute | $73.00-$87.00 | Fixed cluster + 2 nodes |
| RDS Database | $189.54 | Multi-AZ, 20GB gp3, HA ready |
| Networking | $28.54 | NAT, ALB, API Gateway, VPC |
| CDN & WAF | $16.37-100.00 | Depends on data transfer volume |
| Security | $15.14 | CloudTrail, GuardDuty, KMS, etc. |
| Data Transfer | $7.80 | Internet + inter-AZ replication |
| **TOTAL** | **$330.39 - $513.39** | **Base: $330 (minimal traffic)** |

---

## 📈 Cost Breakdown by Service Type

```
Compute (EKS):          26% ($87)
Database (RDS):         57% ($189)
Networking:             9% ($29)
Security/Monitoring:    5% ($15)
CDN/WAF:               2% ($5 base, up to 30% with traffic)
Data Transfer:         2% ($8)
────────────────────────────
TOTAL:                 $330-513/month
```

---

## 💡 Cost Optimization Recommendations

### **High Impact (Save 20-30%)**
1. **Downsize RDS from db.t3.medium to db.t3.small**
   - Saves: ~$58/month
   - Trade-off: Lower performance, suitable for <500 transactions/sec

2. **Use Spot Instances for EKS nodes**
   - Saves: ~$42/month (70% off on-demand)
   - Trade-off: Instances can be interrupted; need load balancing

3. **Disable Multi-AZ on RDS (dev/staging only)**
   - Saves: ~$100/month
   - Trade-off: No HA; not recommended for production

### **Medium Impact (Save 10-15%)**
4. **Implement EKS Cluster Autoscaler**
   - Saves: ~$15-30/month by scaling down when not needed
   - Perfect with current max_size=4

5. **Right-size ALB**
   - Current: $16/month
   - With Network Load Balancer (NLB): $16.44/month (similar cost but better performance)

6. **Optimize CloudTrail retention**
   - Current: 365 days
   - Reduce to: 90 days = saves ~$1/month (minimal)

### **Low Impact (Save <5%)**
7. **Use reserved instances**
   - 1-year: 28% discount
   - 3-year: 40% discount
   - Cost: ~$750/year for current setup vs $4,000 on-demand

8. **Enable S3 Intelligent-Tiering**
   - For CloudTrail/backup logs
   - Saves: ~$0.10-0.20/month (minimal)

---

## 🎯 Recommended Cost Scenarios

### **Development/Staging (Lower Cost)**
```
RDS: db.t3.small + Single AZ
EKS: 1 t3.small node (min_size=1)
CDN: Disabled
Total: ~$150-180/month
```

### **Current Production (Balanced)**
```
RDS: db.t3.medium Multi-AZ
EKS: 2 t3.medium nodes
CDN: Enabled with WAF
Total: ~$330-400/month
```

### **High Availability Production (Premium)**
```
RDS: db.t3.large Multi-AZ
EKS: 3-4 t3.large nodes with auto-scaling
CDN: Enabled with WAF + advanced rules
ALB: NLB instead of ALB
Total: ~$800-1200/month
```

---

## 📊 Monthly Cost Tracking

**Actual Costs (once deployed):**

| Month | Compute | Database | Network | CDN/WAF | Security | Total |
|-------|---------|----------|---------|---------|----------|-------|
| Jan 2026 | $87 | $189 | $29 | $16 | $15 | **$336** |
| Feb 2026 | $87 | $189 | $29 | $16 | $15 | **$336** |
| Mar 2026 | $87 | $189 | $29 | $16 | $15 | **$336** |

**Annual Cost: ~$4,032** (at current configuration)

---

## 🔍 Cost Drivers to Monitor

1. **RDS:** Account for ~57% of costs
   - Scale up DB = +$50-100/month per tier
   - Storage growth: +$0.095 per GB/month

2. **Data Transfer:** If traffic increases significantly
   - CloudFront: $8.50 per 100 GB
   - NAT Gateway: $0.045 per GB egress

3. **EKS Nodes:** If you enable auto-scaling
   - Each additional t3.medium node: +$30/month

4. **Security Services:** Scales with workload
   - GuardDuty: Increases with node count
   - CloudTrail: Increases with API activity

---

## 📞 Next Steps

1. **Validate against AWS Cost Calculator:** https://calculator.aws/#/
2. **Set up AWS Budgets:** Alert when spending exceeds $350/month
3. **Enable Cost Anomaly Detection:** Identify unusual spending patterns
4. **Review Reserved Instance options** if committing 1+ years
5. **Monitor actual spend** in AWS Cost Explorer after deployment

---

**Prepared:** December 31, 2025  
**Valid Through:** March 31, 2026 (pricing subject to AWS changes)  
**Currency:** USD (US-East-1 region pricing)
