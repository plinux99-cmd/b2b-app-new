# NiFi + Keycloak Quick Setup Guide

## Overview
Apache NiFi now supports Keycloak OIDC authentication for SSO integration with your existing Keycloak deployment.

## Prerequisites
- ✅ Keycloak running at: `https://kc2.aerowiseplatform.com`
- ✅ Keycloak realm: `aerowise`
- ✅ Admin user created in Keycloak

## Quick Setup (3 Steps)

### Step 1: Create NiFi Client in Keycloak

```bash
# Login to Keycloak Admin Console
https://kc2.aerowiseplatform.com/admin

# Navigate: Realm: aerowise → Clients → Create Client
```

**Client Configuration:**
```
Client ID: nifi-client
Client Protocol: openid-connect
Access Type: confidential
Standard Flow Enabled: ON

Valid Redirect URIs:
  https://<nifi-ip-or-domain>:8443/nifi-api/access/oidc/callback
  
Web Origins:
  https://<nifi-ip-or-domain>
```

**Get Client Secret:**
- Go to **Credentials** tab
- Copy the **Secret** value

### Step 2: Configure Terraform

Edit `terraform/infra/terraform.tfvars`:

```hcl
# Enable Keycloak authentication
nifi_enable_keycloak_auth     = true
nifi_keycloak_url             = "https://kc2.aerowiseplatform.com"
nifi_keycloak_realm           = "aerowise"
nifi_keycloak_client_id       = "nifi-client"
nifi_admin_identity           = "admin@aerowiseplatform.com"  # Your Keycloak user email
```

**Set client secret (securely):**
```bash
export TF_VAR_nifi_keycloak_client_secret="YOUR_CLIENT_SECRET"
export TF_VAR_db_password="your-db-password"
```

### Step 3: Deploy

```bash
cd terraform/infra
terraform apply -lock=false
```

**Result:**
- ✅ NiFi starts with HTTPS on port 8443
- ✅ OIDC configured automatically
- ✅ Admin user granted full access

## Access NiFi

```bash
# Get NiFi URL
terraform output nifi_instance_private_ip

# Access via HTTPS
https://<private-ip>:8443/nifi

# Click "Log In" → Redirects to Keycloak → Enter credentials
```

## Configuration Summary

### What Gets Configured

| Component | Configuration |
|-----------|--------------|
| **HTTPS** | Port 8443 (HTTP disabled) |
| **OIDC Discovery** | https://kc2.aerowiseplatform.com/realms/aerowise/.well-known/openid-configuration |
| **Client ID** | nifi-client |
| **User Claim** | email |
| **Initial Admin** | admin@aerowiseplatform.com (from terraform.tfvars) |
| **Certificate** | Self-signed (replace in production) |

### Security Features

- ✅ HTTPS/TLS encryption
- ✅ OIDC authentication via Keycloak
- ✅ Keystore & truststore created automatically
- ✅ Admin authorization configured
- ✅ Session management via Keycloak

## Deployment Options

### Option 1: Testing (Current - Self-Signed Cert)
```hcl
nifi_enable_keycloak_auth = true
nifi_associate_public_ip  = false  # Private access only
```

### Option 2: Production (Proper Certificate)
```hcl
nifi_enable_keycloak_auth = true
nifi_associate_public_ip  = false

# After deployment, replace self-signed certificate with:
# - Let's Encrypt certificate
# - AWS ACM certificate (exported)
# - Organization CA certificate
```

### Option 3: Public Access (via ALB)
```hcl
nifi_associate_public_ip = true
# Then create ALB/Ingress with proper certificate
```

## Keycloak User Management

### Create Additional NiFi Users

1. **Keycloak Admin Console** → **Users** → **Add User**
2. Set email and credentials
3. User logs into NiFi → automatically created in NiFi user registry
4. Grant permissions in NiFi UI → Hamburger Menu → Users → Add Policy

### Assign Roles (Optional)

Create Keycloak groups and map to NiFi roles:
```
Keycloak Group: NiFi-Admins → Full access
Keycloak Group: NiFi-Users → Read-only
Keycloak Group: NiFi-DataEngineers → Flow modification
```

## Disable Keycloak (Fallback to Basic Auth)

If you need to disable OIDC:

```hcl
# In terraform.tfvars
nifi_enable_keycloak_auth = false

# Then apply
terraform apply -lock=false
```

NiFi will revert to HTTP on port 8080 without authentication.

## Troubleshooting

### Issue: Cannot Connect to Keycloak

```bash
# SSH into NiFi instance
aws ssm start-session --target <instance-id>

# Test Keycloak connectivity
curl https://kc2.aerowiseplatform.com/realms/aerowise/.well-known/openid-configuration

# Check DNS
nslookup kc2.aerowiseplatform.com
```

**Fix**: Ensure NiFi security group allows outbound HTTPS to Keycloak

### Issue: Redirect URI Mismatch

**Error**: `invalid_redirect_uri`

**Fix**: Update Keycloak client redirect URIs to match exact NiFi URL:
```
https://<actual-nifi-url>:8443/nifi-api/access/oidc/callback
```

### Issue: User Not Authorized

**Fix**: Verify admin identity in terraform.tfvars matches Keycloak user email exactly:
```hcl
nifi_admin_identity = "admin@aerowiseplatform.com"  # Must match Keycloak email
```

Then `terraform apply` to update.

## Production Checklist

- [ ] Replace self-signed certificate with proper CA cert
- [ ] Change keystore password from `changeit`
- [ ] Restrict NiFi access to VPN/private network
- [ ] Enable Keycloak MFA for admin users
- [ ] Set up CloudWatch alarms for auth failures
- [ ] Store client secret in AWS Secrets Manager
- [ ] Configure proper redirect URIs (no wildcards)
- [ ] Enable NiFi audit logging
- [ ] Test failover and disaster recovery

## Variables Reference

### Terraform Variables (terraform.tfvars)

```hcl
# NiFi Keycloak Authentication
nifi_enable_keycloak_auth     = true/false           # Enable OIDC
nifi_keycloak_url             = "https://kc2..."    # Keycloak URL
nifi_keycloak_realm           = "aerowise"          # Realm name
nifi_keycloak_client_id       = "nifi-client"       # Client ID
nifi_admin_identity           = "admin@email.com"   # Admin email
```

### Environment Variables (Secrets)

```bash
export TF_VAR_nifi_keycloak_client_secret="..."  # Keycloak client secret
export TF_VAR_db_password="..."                   # Database password
```

## Cost Impact

Keycloak OIDC integration adds:
- **$0/month** (uses existing Keycloak deployment)
- **CPU**: Minimal overhead (~1% increase)
- **Network**: ~10 KB per login (OIDC token exchange)

No additional AWS costs.

## Full Documentation

- **Detailed Guide**: `terraform/infra/scripts/NIFI_KEYCLOAK_INTEGRATION.md`
- **NiFi Setup**: `terraform/infra/scripts/NIFI_SETUP.md`
- **Quick Start**: `NIFI_QUICKSTART.md`

---

**Status**: ✅ Ready to deploy with Keycloak authentication

**Next Steps**:
1. Create NiFi client in Keycloak
2. Set `nifi_enable_keycloak_auth = true`
3. Run `terraform apply`
4. Access NiFi via Keycloak SSO
