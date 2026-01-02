# Keycloak Deployment Guide (with Terraform RDS)

## Overview
This guide shows how to deploy Keycloak to Kubernetes using the RDS PostgreSQL database created by Terraform.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌────────────────┐
│   Internet      │────────▶│  ALB (HTTPS)     │────────▶│  Keycloak Pod  │
│   (Users)       │         │  kc2.aerowise... │         │  (Kubernetes)  │
└─────────────────┘         └──────────────────┘         └────────────────┘
                                                                   │
                                                                   │ JDBC
                                                                   ▼
                                                          ┌────────────────┐
                                                          │  RDS Postgres  │
                                                          │  (Terraform)   │
                                                          └────────────────┘
```

## Prerequisites

### 1. Terraform Infrastructure Deployed
Ensure your Terraform infrastructure is already deployed:

```bash
cd terraform/infra
terraform apply -lock=false
```

**Required resources created:**
- ✅ VPC and subnets
- ✅ EKS cluster
- ✅ RDS PostgreSQL database
- ✅ Security groups
- ✅ AWS Load Balancer Controller

### 2. Get Terraform Outputs

```bash
cd terraform/infra

# Get RDS endpoint
terraform output -raw rds_endpoint
# Output: aerowise-t1-postgres.xxxxx.us-east-1.rds.amazonaws.com

# Get VPC ID
terraform output -raw vpc_id

# Get EKS cluster name
terraform output -raw eks_cluster_name
```

### 3. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --name aerowise-t1-eks --region us-east-1

# Verify connection
kubectl get nodes
```

## Database Setup

### Step 1: Create Keycloak Database in RDS

```bash
# Get RDS endpoint from Terraform
RDS_ENDPOINT=$(cd terraform/infra && terraform output -raw rds_endpoint)
DB_PASSWORD="your-db-password"  # Same as terraform.tfvars

# Connect to RDS (from a pod or bastion host with psql)
kubectl run -it --rm psql-client --image=postgres:17 --restart=Never -- \
  psql "postgresql://postgres:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/postgres?sslmode=require"

# Inside psql:
CREATE DATABASE keycloak;
CREATE USER keycloak WITH PASSWORD 'keycloakSecurePass123!';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
\q
```

**Alternative: Use existing `postgres` user** (simpler for testing):
```sql
-- Just create the database, use existing postgres user
CREATE DATABASE keycloak;
```

### Step 2: Verify Database Connection

```bash
# Test connection to keycloak database
kubectl run -it --rm psql-client --image=postgres:17 --restart=Never -- \
  psql "postgresql://postgres:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/keycloak?sslmode=require"

# Should connect successfully and show keycloak database
\l  # List databases
\q
```

## Keycloak Deployment

### Step 1: Update Configuration Files

Edit `kubernetes/keycloak-deployment.yaml`:

**Update ConfigMap with your RDS endpoint:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-config
  namespace: mobileapp
data:
  # Replace with your actual RDS endpoint from Terraform output
  KC_DB_URL_HOST: "aerowise-t1-postgres.c7i08ukwctz8.us-east-1.rds.amazonaws.com"
  KC_DB_URL_DATABASE: "keycloak"
  KC_DB_URL_PORT: "5432"
```

**Update Secret with your database password:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: mobileapp
type: Opaque
stringData:
  KC_DB_USERNAME: postgres
  KC_DB_PASSWORD: "YOUR_ACTUAL_DB_PASSWORD"  # From terraform.tfvars
```

**Update admin credentials:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-admin-secret
  namespace: mobileapp
type: Opaque
stringData:
  KEYCLOAK_ADMIN: admin
  KEYCLOAK_ADMIN_PASSWORD: "YourSecureAdminPassword123!"  # Change this!
```

### Step 2: Deploy Keycloak

```bash
# Apply namespace (if not exists)
kubectl apply -f kubernetes/keycloak-deployment.yaml

# Verify deployment
kubectl get pods -n mobileapp -l app=keycloak -w

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# keycloak-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# keycloak-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 3: Check Logs

```bash
# View startup logs
kubectl logs -n mobileapp -l app=keycloak --tail=100 -f

# Look for successful messages:
# ✓ Database migration completed
# ✓ Keycloak started successfully
# ✓ Listening on http://0.0.0.0:8080
```

### Step 4: Deploy Ingress

```bash
# Deploy ALB Ingress
kubectl apply -f kubernetes/keycloak-ingress.yaml

# Wait for ALB to be provisioned (~2-3 minutes)
kubectl get ingress -n mobileapp keycloak-ingress -w

# Get ALB DNS name
kubectl get ingress -n mobileapp keycloak-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 5: Update DNS

Point your domain to the ALB:

```bash
# Get ALB DNS
ALB_DNS=$(kubectl get ingress -n mobileapp keycloak-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Create CNAME record:"
echo "kc2.aerowiseplatform.com -> $ALB_DNS"
```

In your DNS provider (Route 53, Cloudflare, etc.):
```
Type: CNAME
Name: kc2.aerowiseplatform.com
Value: <ALB-DNS-from-above>
TTL: 300
```

## Verification

### Step 1: Health Checks

```bash
# Check health endpoint directly on pod
POD=$(kubectl get pod -n mobileapp -l app=keycloak -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mobileapp $POD -- curl -s http://localhost:9000/health

# Expected output (JSON):
# {"status":"UP","checks":[...]}
```

### Step 2: Access Keycloak

```bash
# Via ALB (once DNS propagates)
curl -v https://kc2.aerowiseplatform.com/health/ready

# Should return 200 OK

# Access admin console
open https://kc2.aerowiseplatform.com/admin
```

### Step 3: Login to Admin Console

1. Open: `https://kc2.aerowiseplatform.com/admin`
2. Username: `admin`
3. Password: (from keycloak-admin-secret)
4. Should see Keycloak admin dashboard

### Step 4: Verify Database Connection

```bash
# Check Keycloak logs for database connectivity
kubectl logs -n mobileapp -l app=keycloak | grep -i "database"

# Should see successful connection messages
# No "connection refused" or "authentication failed" errors
```

## RDS Connection Details

### Security Group Configuration

Keycloak pods connect to RDS via:
- **Source**: EKS node security group
- **Destination**: RDS security group (port 5432)
- **Protocol**: PostgreSQL (TCP/5432)

This is already configured by Terraform in:
```hcl
# terraform/modules/rds/main.tf
resource "aws_security_group_rule" "rds_ingress_from_eks" {
  # Allows EKS nodes to connect to RDS
}
```

### Connection String Format

```
jdbc:postgresql://aerowise-t1-postgres.<region>.rds.amazonaws.com:5432/keycloak?ssl=true&sslmode=require
```

Components:
- **Host**: RDS endpoint (from Terraform output)
- **Port**: 5432 (PostgreSQL default)
- **Database**: `keycloak`
- **SSL**: Required (RDS enforces SSL)

## Troubleshooting

### Issue 1: Keycloak Pods CrashLoopBackOff

```bash
# Check logs
kubectl logs -n mobileapp -l app=keycloak --tail=50

# Common causes:
# 1. Database connection failed
# 2. Wrong database credentials
# 3. Database not created
# 4. Network connectivity issues
```

**Fix**:
```bash
# Verify RDS endpoint is correct
cd terraform/infra
terraform output rds_endpoint

# Update ConfigMap with correct endpoint
kubectl edit configmap keycloak-config -n mobileapp

# Verify database exists
kubectl run -it --rm psql-client --image=postgres:17 --restart=Never -- \
  psql "postgresql://postgres:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/postgres?sslmode=require" \
  -c "\l"
```

### Issue 2: Cannot Connect to Database

```bash
# Check security groups allow EKS → RDS on port 5432
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=<rds-sg-id>" | grep 5432

# Test connectivity from pod
kubectl run -it --rm netcat --image=busybox --restart=Never -- \
  nc -zv aerowise-t1-postgres.<region>.rds.amazonaws.com 5432
```

**Fix**: Ensure Terraform has created the security group rule allowing EKS nodes to RDS.

### Issue 3: ALB Health Checks Failing

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]'

# Common issues:
# - Health check path wrong (/health/ready should work)
# - Pods not ready
# - Security group blocking ALB → Pods
```

**Fix**:
```bash
# Verify health endpoint
kubectl exec -n mobileapp <keycloak-pod> -- curl localhost:9000/health/ready

# Check ingress annotations
kubectl get ingress keycloak-ingress -n mobileapp -o yaml | grep healthcheck
```

### Issue 4: DNS Not Resolving

```bash
# Check DNS propagation
nslookup kc2.aerowiseplatform.com

# Should return ALB IP addresses
# If not, verify CNAME record in DNS provider
```

## Configuration Details

### Environment Variables (ConfigMap/Secrets)

| Variable | Source | Description |
|----------|--------|-------------|
| `KC_DB_URL_HOST` | Terraform output | RDS endpoint |
| `KC_DB_URL_DATABASE` | ConfigMap | Database name (keycloak) |
| `KC_DB_USERNAME` | Secret | postgres |
| `KC_DB_PASSWORD` | Secret | From terraform.tfvars |
| `KEYCLOAK_ADMIN` | Secret | Admin username |
| `KEYCLOAK_ADMIN_PASSWORD` | Secret | Admin password |

### Resource Limits

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "3Gi"
    cpu: "2000m"
```

Adjust based on load:
- **Light usage**: 1Gi/0.5 CPU
- **Medium usage**: 2Gi/1 CPU (current)
- **Heavy usage**: 4Gi/2 CPU

### Database Connection Pool

```yaml
KC_DB_POOL_INITIAL_SIZE: "5"
KC_DB_POOL_MIN_SIZE: "5"
KC_DB_POOL_MAX_SIZE: "20"
```

Tune based on:
- RDS instance size (db.t3.medium = 78 max connections)
- Number of Keycloak replicas (2 replicas × 20 = 40 connections max)
- Leave headroom for other applications

## Scaling

### Horizontal Scaling

```bash
# Scale Keycloak deployment
kubectl scale deployment keycloak -n mobileapp --replicas=3

# Verify
kubectl get pods -n mobileapp -l app=keycloak
```

**Considerations:**
- Each replica needs ~20 database connections
- RDS max connections = 78 (for db.t3.medium)
- Recommended max replicas = 3 (60 connections + buffer)

### Vertical Scaling

```yaml
# Increase resources
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "6Gi"
    cpu: "4000m"
```

## Maintenance

### Database Backup

RDS backups are handled by Terraform:
```hcl
# terraform/modules/rds/main.tf
backup_retention_period = 7  # Keep 7 days of backups
```

### Upgrade Keycloak

```bash
# Update image tag
kubectl set image deployment/keycloak \
  -n mobileapp keycloak=<ecr-repo>/keycloak:27.0.0

# Or edit deployment
kubectl edit deployment keycloak -n mobileapp
```

### Database Migration

Keycloak automatically migrates database schema on startup.

```bash
# Check migration logs
kubectl logs -n mobileapp -l app=keycloak | grep -i "migration"
```

## Production Checklist

- [ ] RDS endpoint updated in ConfigMap
- [ ] Database password set in Secret (from terraform.tfvars)
- [ ] Admin password changed from default
- [ ] SSL/TLS certificate configured (ACM)
- [ ] DNS CNAME record created
- [ ] Health checks passing
- [ ] Replicas set appropriately (2-3)
- [ ] Resource limits configured
- [ ] Monitoring/alerts configured
- [ ] Backup strategy verified
- [ ] Security groups reviewed

## Cost Estimate

| Component | Specs | Monthly Cost |
|-----------|-------|--------------|
| RDS (existing) | db.t3.medium | ~$293 (from Terraform) |
| Keycloak Pods | 2 × 2GB/1CPU | ~$30 (EKS node allocation) |
| ALB | 1 × Application LB | ~$23 |
| **Total** | | **~$346/month** |

**Note**: RDS cost already included in infrastructure total (~$644/month)

## Next Steps

1. ✅ Deploy Keycloak to Kubernetes
2. ✅ Create realms and clients
3. ✅ Configure NiFi client (see NIFI_KEYCLOAK_QUICKSTART.md)
4. ✅ Set up user federation (LDAP/AD if needed)
5. ✅ Enable MFA for admin users
6. ✅ Configure backup/disaster recovery

---

**Related Documentation:**
- `NIFI_KEYCLOAK_QUICKSTART.md` - NiFi + Keycloak integration
- `terraform/infra/scripts/NIFI_KEYCLOAK_INTEGRATION.md` - Detailed integration guide
- `kubernetes/keycloak-deployment.yaml` - Deployment manifest
- `kubernetes/keycloak-ingress.yaml` - Ingress configuration
