# NiFi Quick Start - 5 Minute Setup

## What's Been Created

✅ Complete Apache NiFi Terraform module with:
- **m5.2xlarge EC2 instance** (8 vCPU, 32 GB RAM)
- **128 GB gp3 EBS volume** for data storage
- **Automated daily snapshots** (14-day retention via DLM)
- **CloudWatch monitoring** and alarms
- **IAM roles** with least privilege access
- **Security group** with restricted network rules
- **Installation automation** via user_data script

## Quick Deployment (3 Steps)

### Step 1: Configure (Edit terraform.tfvars)
```bash
cd terraform/infra

# Edit terraform.tfvars and set:
create_nifi_ec2 = true
nifi_ssh_allowed_cidr = ["YOUR_OFFICE_IP/32"]  # Change this!
```

### Step 2: Deploy
```bash
terraform init  # (if needed)
TF_VAR_db_password="your-password" terraform apply -lock=false
```

Expected: ~25-30 minutes for full deployment

### Step 3: Verify
```bash
cd scripts
./verify-nifi.sh aerowise-t1 us-east-1
```

## Access NiFi

**From within VPC** (Recommended):
```bash
# Get the private IP
terraform output nifi_instance_private_ip

# Access from another VPC resource:
http://<private-ip>:8080/nifi
```

**Via SSH** (without key files):
```bash
INSTANCE_ID=$(terraform output -raw nifi_instance_id)
aws ssm start-session --target $INSTANCE_ID --region us-east-1

# Inside the instance:
sudo systemctl status nifi
sudo tail -f /opt/nifi/current/logs/nifi-app.log
```

## Key Features

| Feature | Details |
|---------|---------|
| **Instance Type** | m5.2xlarge (8 vCPU, 32 GB) |
| **Storage** | 128 GB gp3 |
| **NiFi Version** | 1.25.0 (LTS) |
| **Snapshots** | Daily, 14-day retention (~$1/month) |
| **Monitoring** | CloudWatch with disk/memory alerts |
| **Security** | VPC-isolated, KMS encryption, IAM roles |
| **Recovery** | Automated snapshots + DLM |

## Important Variables

```hcl
# In terraform.tfvars:

# Enable/disable
create_nifi_ec2 = true

# Instance sizing
nifi_instance_type = "m5.2xlarge"     # Don't change unless needed
nifi_storage_size = 128               # GB

# Network
nifi_ssh_allowed_cidr = ["10.0.0.0/16"]  # Update for your IP!
nifi_associate_public_ip = false       # Set true for public internet

# Snapshots
nifi_snapshot_retention_count = 14     # Days of backups

# Encryption
nifi_ebs_encryption_enabled = true     # Keep enabled
```

## Monitoring

### Check Instance Status
```bash
terraform output nifi_instance_id
aws ec2 describe-instances --instance-ids <id> --region us-east-1
```

### View CloudWatch Alarms
```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix aerowise-t1-nifi \
  --region us-east-1
```

### Monitor Disk Usage
```bash
# SSH into instance, then:
df -h /nifi_data
du -sh /nifi_data/*
```

## File System Layout

```
/opt/nifi/current/        # NiFi installation
/nifi_data/               # Data volume (128 GB)
  ├── flow.xml.gz         # Flow configuration
  ├── content_repository/ # Data storage
  ├── provenance_repo/    # Audit logs
  └── archive/            # Backups
```

## Backup & Recovery

### Manual Snapshot
```bash
VOLUME_ID=$(terraform output -raw nifi_ebs_volume_id)
aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Manual backup"
```

### Restore from Snapshot
```bash
# 1. Create volume from snapshot
aws ec2 create-volume \
  --snapshot-id snap-xxxxx \
  --availability-zone us-east-1a \
  --volume-type gp3

# 2. Attach and mount
aws ec2 attach-volume \
  --volume-id vol-new \
  --instance-id i-xxxxx \
  --device /dev/sdf

sudo mount /dev/nvme2n1 /mnt/recovery
```

## Cost (~$297/month)

| Component | Cost |
|-----------|------|
| EC2 m5.2xlarge | $280 |
| EBS volume (128 GB) | $13 |
| Snapshots (14/month) | $1 |
| CloudWatch & KMS | $3 |
| **Total** | **~$297/month** |

*(Prices for us-east-1; other regions may vary)*

## Troubleshooting

**NiFi not starting?**
```bash
sudo systemctl status nifi
sudo systemctl restart nifi
sudo tail -f /opt/nifi/current/logs/nifi-app.log
```

**Disk full?**
```bash
df -h /nifi_data
du -sh /nifi_data/*

# Expand volume in terraform.tfvars:
nifi_storage_size = 256  # Increase from 128
terraform apply
```

**Connection issues?**
```bash
# Check security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw nifi_security_group_id)

# Test connectivity
telnet <private-ip> 8080
```

## Full Documentation

- **Detailed Setup**: `terraform/infra/scripts/NIFI_SETUP.md` (50+ pages)
- **Module Code**: `terraform/modules/nifi-ec2/`
- **Implementation**: `NIFI_EC2_IMPLEMENTATION.md`
- **Validation**: `terraform/infra/scripts/verify-nifi.sh`

## Next Steps

1. ✅ Edit `terraform.tfvars` (set your IP address)
2. ✅ Run `terraform apply`
3. ✅ Run validation script
4. ✅ Access NiFi at private IP
5. ✅ Configure your flows!

---

**Status**: Ready to deploy! Follow the 3-step Quick Deployment above.
