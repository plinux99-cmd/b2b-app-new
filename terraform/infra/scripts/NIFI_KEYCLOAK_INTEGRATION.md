# Apache NiFi + Keycloak Integration Guide

## Overview
This guide explains how to integrate Apache NiFi with Keycloak for OIDC-based authentication and Single Sign-On (SSO).

## Architecture

```
┌────────────────┐         ┌──────────────┐         ┌─────────────┐
│   User Browser │────────▶│   Keycloak   │◀───────│  NiFi EC2   │
│                │  OIDC   │  (Kubernetes)│  OIDC  │  Instance   │
└────────────────┘         └──────────────┘         └─────────────┘
                                  │
                                  │ Auth DB
                                  ▼
                           ┌──────────────┐
                           │ RDS Postgres │
                           └──────────────┘
```

## Prerequisites

### 1. Keycloak Deployment
Your Keycloak instance must be running with:
- ✅ **URL**: https://kc2.aerowiseplatform.com
- ✅ **Realm**: `aerowise` (or your custom realm)
- ✅ **RDS Database**: PostgreSQL with `keycloak` database
- ✅ **Ingress**: ALB with HTTPS/SSL certificate
- ✅ **Health checks**: `/health/ready`, `/health/live`, `/health/started`

### 2. Keycloak Client Configuration
You need to create a Keycloak client for NiFi:

#### Create NiFi Client in Keycloak:

1. **Log into Keycloak Admin Console**:
   ```bash
   https://kc2.aerowiseplatform.com/admin
   ```

2. **Navigate to Clients**:
   - Realm: `aerowise` → Clients → Create Client

3. **Client Settings**:
   ```
   Client ID: nifi-client
   Client Protocol: openid-connect
   Access Type: confidential
   Standard Flow Enabled: ON
   Direct Access Grants Enabled: ON
   Valid Redirect URIs: 
     - https://<nifi-domain-or-ip>:8443/nifi-api/access/oidc/callback
     - https://<nifi-alb-dns>:8443/nifi-api/access/oidc/callback
   Web Origins: 
     - https://<nifi-domain>
   ```

4. **Get Client Secret**:
   - Go to **Credentials** tab
   - Copy the **Secret** value
   - Save it securely (you'll need it for Terraform)

5. **Configure Mappers** (Optional but recommended):
   - Go to **Client Scopes** → **nifi-client-dedicated** → **Mappers**
   - Add mapper for email:
     ```
     Name: email
     Mapper Type: User Property
     Property: email
     Token Claim Name: email
     Claim JSON Type: String
     Add to ID token: ON
     Add to access token: ON
     Add to userinfo: ON
     ```

### 3. Create Admin User in Keycloak

1. Navigate to **Users** → **Add User**
2. Set username: `admin@aerowiseplatform.com` (or your email)
3. Set email: `admin@aerowiseplatform.com`
4. Email Verified: **ON**
5. Save, then go to **Credentials** tab and set password

## Terraform Configuration

### Step 1: Enable Keycloak in terraform.tfvars

Edit `terraform/infra/terraform.tfvars`:

```hcl
# NiFi Keycloak OIDC Authentication
nifi_enable_keycloak_auth     = true
nifi_keycloak_url             = "https://kc2.aerowiseplatform.com"
nifi_keycloak_realm           = "aerowise"
nifi_keycloak_client_id       = "nifi-client"
# Set client secret via environment variable (see below)
nifi_admin_identity           = "admin@aerowiseplatform.com"  # Must match Keycloak user email
```

### Step 2: Set Client Secret (Securely)

**Option A - Environment Variable** (Recommended):
```bash
export TF_VAR_nifi_keycloak_client_secret="YOUR_CLIENT_SECRET_HERE"
export TF_VAR_db_password="your-db-password"
```

**Option B - Kubernetes Secret** (if using K8s for NiFi):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nifi-keycloak-secret
  namespace: mobileapp
type: Opaque
stringData:
  KEYCLOAK_CLIENT_SECRET: "YOUR_CLIENT_SECRET_HERE"
```

### Step 3: Deploy NiFi with Keycloak

```bash
cd terraform/infra

# Set secrets
export TF_VAR_nifi_keycloak_client_secret="4W20CbOZlMZLt9biiXryz87JzXyJCdY8"  # Example
export TF_VAR_db_password="your-db-password"

# Apply configuration
terraform init
terraform plan -lock=false
terraform apply -lock=false
```

Expected:
- NiFi will start with **HTTPS enabled on port 8443**
- HTTP port 8080 will be disabled
- OIDC authentication will be configured

## NiFi Configuration Details

### What Gets Configured Automatically

When `nifi_enable_keycloak_auth = true`, the Terraform module automatically:

1. **Enables HTTPS**:
   - Port 8443 enabled
   - Self-signed certificate generated (replace in production)
   - Keystore and truststore created

2. **Configures OIDC in nifi.properties**:
   ```properties
   nifi.security.user.oidc.discovery.url=https://kc2.aerowiseplatform.com/realms/aerowise/.well-known/openid-configuration
   nifi.security.user.oidc.client.id=nifi-client
   nifi.security.user.oidc.client.secret=YOUR_SECRET
   nifi.security.user.oidc.claim.identifying.user=email
   ```

3. **Creates Initial Admin in authorizers.xml**:
   ```xml
   <property name="Initial Admin Identity">admin@aerowiseplatform.com</property>
   ```

4. **Generates Keystore/Truststore**:
   - Location: `/opt/nifi/current/conf/keystore.jks`
   - Password: `changeit` (default, change in production)

## Accessing NiFi with Keycloak

### Step 1: Get NiFi URL

```bash
# Get private IP
terraform output nifi_instance_private_ip

# If using ALB/Ingress (recommended):
# Create Kubernetes Ingress for NiFi (see example below)
```

### Step 2: Access via HTTPS

```
https://<nifi-ip-or-domain>:8443/nifi
```

### Step 3: Login Flow

1. Click **"Log In"** on NiFi UI
2. Redirected to Keycloak login page
3. Enter credentials: `admin@aerowiseplatform.com`
4. Redirected back to NiFi with admin access

## Production Deployment Options

### Option 1: NiFi via ALB Ingress (Recommended)

Create Kubernetes Ingress for NiFi (similar to Keycloak):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nifi-ingress
  namespace: mobileapp
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/backend-protocol: HTTPS
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxx
    alb.ingress.kubernetes.io/healthcheck-path: /nifi
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
spec:
  ingressClassName: alb
  rules:
    - host: nifi.aerowiseplatform.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nifi-service
                port:
                  number: 8443
```

**Note**: For ALB integration, you'll need to convert the NiFi EC2 to a Kubernetes deployment or use Target Groups.

### Option 2: Direct EC2 Access via VPN

1. Set up AWS Client VPN or VPN Gateway
2. Access NiFi directly: `https://<private-ip>:8443/nifi`
3. Update Keycloak redirect URIs with private IP

### Option 3: Public ALB with Security Groups

1. Create internet-facing ALB
2. Target: NiFi EC2 instance (port 8443)
3. SSL certificate on ALB
4. Security group: restrict to office IPs

## Certificate Management (Production)

### Replace Self-Signed Certificate

1. **SSH into NiFi instance**:
   ```bash
   aws ssm start-session --target <instance-id>
   ```

2. **Generate proper certificate**:
   ```bash
   # Option A: Let's Encrypt
   sudo certbot certonly --standalone -d nifi.aerowiseplatform.com
   
   # Option B: Use AWS ACM certificate (export and convert)
   # Or use your organization's CA certificate
   ```

3. **Update keystore**:
   ```bash
   sudo keytool -importkeystore \
     -srckeystore /etc/letsencrypt/live/nifi.aerowiseplatform.com/fullchain.pem \
     -destkeystore /opt/nifi/current/conf/keystore.jks \
     -deststoretype JKS -deststorepass changeit
   ```

4. **Restart NiFi**:
   ```bash
   sudo systemctl restart nifi
   ```

## Troubleshooting

### Issue 1: "Unable to log in" Error

**Cause**: OIDC discovery URL not reachable from NiFi instance

**Solution**:
```bash
# SSH into NiFi instance
aws ssm start-session --target <instance-id>

# Test connectivity to Keycloak
curl -v https://kc2.aerowiseplatform.com/realms/aerowise/.well-known/openid-configuration

# Check DNS resolution
nslookup kc2.aerowiseplatform.com

# If private: ensure security group allows egress to internet
# If using VPC endpoints: add privatelink endpoint for external domains
```

### Issue 2: Redirect URI Mismatch

**Error**: `invalid_redirect_uri` from Keycloak

**Solution**:
1. Check NiFi URL in browser
2. Verify exact match in Keycloak client settings:
   ```
   Valid Redirect URIs:
   https://<exact-nifi-url>:8443/nifi-api/access/oidc/callback
   ```
3. Add wildcard if needed: `https://*.aerowiseplatform.com:8443/*`

### Issue 3: User Not Authorized

**Error**: "User is not authorized to access NiFi"

**Solution**:
```bash
# SSH into NiFi instance
aws ssm start-session --target <instance-id>

# Check authorizers.xml
cat /opt/nifi/current/conf/authorizers.xml | grep "Initial Admin"

# Verify admin identity matches Keycloak user email exactly
# Edit if needed:
sudo vi /opt/nifi/current/conf/authorizers.xml

# Update to match Keycloak user:
<property name="Initial Admin Identity">admin@aerowiseplatform.com</property>

# Restart NiFi
sudo systemctl restart nifi
```

### Issue 4: Certificate Errors

**Error**: "Certificate not trusted" or SSL errors

**Solution**:
```bash
# For testing: accept self-signed cert in browser
# For production: replace with proper certificate (see above)

# Verify certificate
openssl s_client -connect <nifi-ip>:8443 -showcerts

# Check keystore
sudo keytool -list -keystore /opt/nifi/current/conf/keystore.jks \
  -storepass changeit
```

## Multi-Node NiFi Cluster with Keycloak

For production HA setup:

1. **Deploy 3 NiFi Instances**:
   ```hcl
   # In terraform.tfvars
   nifi_cluster_size = 3
   ```

2. **Configure Cluster in nifi.properties**:
   ```properties
   nifi.cluster.is.node=true
   nifi.cluster.node.address=<node-ip>
   nifi.cluster.node.protocol.port=6007
   nifi.zookeeper.connect.string=zk1:2181,zk2:2181,zk3:2181
   ```

3. **Update Keycloak Redirect URIs**:
   - Add all node IPs or use load balancer URL

4. **Shared Authentication**:
   - All nodes use same Keycloak configuration
   - User authenticated on any node has access to all nodes

## Security Checklist

- [ ] Replace self-signed certificate with proper CA certificate
- [ ] Change keystore/truststore password from `changeit`
- [ ] Restrict NiFi access to VPN or private network
- [ ] Enable Keycloak MFA for admin users
- [ ] Rotate Keycloak client secret regularly
- [ ] Monitor NiFi logs in CloudWatch
- [ ] Set up CloudWatch alarms for authentication failures
- [ ] Review and restrict Keycloak redirect URIs
- [ ] Use AWS Secrets Manager for Keycloak client secret
- [ ] Enable audit logging in NiFi

## Reference Documentation

- **NiFi OIDC Configuration**: https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#openid_connect
- **Keycloak OIDC**: https://www.keycloak.org/docs/latest/server_admin/#_oidc
- **Data on EKS NiFi Blueprint**: https://awslabs.github.io/data-on-eks/docs/blueprints/streaming-platforms/nifi
- **Medium Article**: https://medium.com/@danielmehrani/building-a-secure-apache-nifi-3-node-cluster-with-nifi-registry-and-keycloak-user-management-c6cc48a7d465

## Support

For issues:
1. Check NiFi logs: `/opt/nifi/current/logs/nifi-app.log`
2. Check Keycloak logs: `kubectl logs -n mobileapp deployment/keycloak`
3. Verify network connectivity between NiFi and Keycloak
4. Confirm Keycloak client configuration matches NiFi settings
