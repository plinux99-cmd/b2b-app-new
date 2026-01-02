# Apache NiFi EC2 Setup Documentation

## Overview
This Terraform module creates a production-ready Apache NiFi instance with:
- **Instance Type**: m5.2xlarge (8 vCPU, 32 GiB RAM)
- **Storage**: 128 GB EBS volume (gp3) with automatic snapshots
- **Automatic Backups**: Daily snapshots retained for 14 days via AWS Data Lifecycle Manager (DLM)
- **Monitoring**: CloudWatch metrics and alarms for disk usage and instance health
- **Security**: VPC integration with security groups, IAM roles, and optional public IP

## Architecture

### Components
1. **EC2 Instance**: m5.2xlarge running Amazon Linux 2
2. **EBS Volume**: 128 GB gp3 volume for NiFi data
3. **Security Group**: Managed ingress/egress rules
4. **IAM Role**: Service role with snapshot creation permissions
5. **Data Lifecycle Manager (DLM)**: Automated daily snapshots
6. **CloudWatch**: Monitoring and alarms

### Network Architecture
```
Internet
    |
    └─> Security Group (port 8080, 8443, 6007, 22)
            |
            └─> EC2 Instance (m5.2xlarge)
                    |
                    ├─> Root Volume (50 GB gp3)
                    └─> Data Volume (128 GB gp3)
```

## Configuration

### Terraform Variables (in `terraform.tfvars`)
```hcl
create_nifi_ec2               = true
nifi_instance_type            = "m5.2xlarge"
nifi_storage_size             = 128              # GB
nifi_ebs_volume_type          = "gp3"
nifi_version                  = "1.25.0"
nifi_ssh_allowed_cidr         = ["10.0.0.0/16"] # Your CIDR
nifi_associate_public_ip      = false            # Set to true if needed
nifi_ebs_encryption_enabled   = true
nifi_snapshot_retention_count = 14               # Daily snapshots for 2 weeks
```

### Default Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Instance Type | m5.2xlarge | 8 vCPU, 32 GiB RAM |
| Storage Size | 128 GB | /nifi_data volume |
| EBS Type | gp3 | General purpose, cost-effective |
| Root Volume | 50 GB | OS and software |
| NiFi Version | 1.25.0 | Latest stable LTS |
| Snapshots | Daily, 14-day retention | 2 weeks of backups |
| Encryption | Enabled | AES-256 with KMS |
| Public IP | Disabled | Set `nifi_associate_public_ip = true` to enable |

## Deployment

### Prerequisites
1. Terraform infra stack must be deployed first: `cd terraform/infra && terraform apply`
2. VPC and subnets must be created
3. KMS key should exist (for encryption)
4. IAM permissions to create EC2, EBS, DLM, and IAM resources

### Step 1: Configure NiFi Settings
Edit `terraform/infra/terraform.tfvars`:
```hcl
create_nifi_ec2         = true
nifi_ssh_allowed_cidr   = ["YOUR_OFFICE_IP/32"]  # Your public IP or CIDR
nifi_associate_public_ip = false                  # true if direct internet access needed
```

### Step 2: Initialize Terraform
```bash
cd terraform/infra
terraform init
```

### Step 3: Plan Deployment
```bash
TF_VAR_db_password="your-password" terraform plan -out=tfplan
```

Review the plan to verify NiFi resources are listed.

### Step 4: Apply Configuration
```bash
TF_VAR_db_password="your-password" terraform apply tfplan
```

Expected output:
```
Apply complete! Resources added: 15
  - aws_instance.nifi
  - aws_ebs_volume.nifi_data
  - aws_dlm_lifecycle_policy.nifi_snapshots
  - aws_cloudwatch_metric_alarm.nifi_disk_usage
  - ... and more
```

### Step 5: Get NiFi Connection Details
```bash
terraform output nifi_instance_private_ip
terraform output nifi_web_ui_url
terraform output nifi_security_group_id
```

## Access NiFi

### Option 1: From within VPC (Recommended)
1. Connect to an EC2 instance or EKS node in the same VPC
2. Access via private IP: `http://10.0.x.x:8080/nifi`
3. Or use the output: `terraform output nifi_web_ui_url`

### Option 2: Direct Access (if public IP enabled)
1. Enable public IP in `terraform.tfvars`: `nifi_associate_public_ip = true`
2. Apply changes: `terraform apply`
3. Access: `http://<public-ip>:8080/nifi`

### Option 3: Load Balancer / API Gateway
Configure security group to allow traffic from ALB:
```hcl
nifi_alb_security_group_id = module.network.vpc_link_sg_id  # Already configured
```

## File System Layout

After deployment, NiFi uses the following directory structure:

```
/nifi_data/
├── flow.xml.gz                      # Flow configuration
├── archive/                         # Flow history
├── database_repository/             # Repository DB
├── flowfile_repository/             # FlowFile state
├── content_repository/              # Content storage (largest)
└── provenance_repository/           # Audit logs

/opt/nifi/
├── current -> nifi-1.25.0          # Symlink to active version
└── nifi-1.25.0/
    ├── bin/                         # Scripts (nifi.sh)
    ├── conf/                        # Config files
    └── lib/                         # JAR files
```

## Snapshots and Backups

### Automatic Snapshots
- **Frequency**: Daily at 03:00 UTC
- **Retention**: 14 days (configurable via `nifi_snapshot_retention_count`)
- **Manager**: AWS Data Lifecycle Manager (DLM)
- **Cost**: ~$0.08 per snapshot per month

### Manual Snapshot
```bash
# Create manual snapshot via AWS CLI
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "Manual NiFi backup"
```

### Restore from Snapshot
```bash
# 1. Create new volume from snapshot
aws ec2 create-volume \
  --snapshot-id snap-xxxxx \
  --availability-zone us-east-1a \
  --volume-type gp3

# 2. Attach to instance and mount
aws ec2 attach-volume \
  --volume-id vol-new \
  --instance-id i-xxxxx \
  --device /dev/sdf

# 3. Mount filesystem
sudo mount /dev/nvme2n1 /nifi_data
```

## Monitoring

### CloudWatch Metrics
Dashboard metrics available at:
```
Namespace: NiFi/aerowise-t1
Metrics:
  - disk_used_percent (CloudWatch Agent)
  - mem_used_percent (CloudWatch Agent)
  - StatusCheckFailed (EC2)
```

### CloudWatch Alarms
Two alarms are automatically created:

1. **Instance Status Check**: Triggers if instance health check fails
   - Alarm: `aerowise-t1-nifi-instance-status`
   - Threshold: 2 consecutive failures

2. **Disk Usage**: Triggers if disk usage exceeds 80%
   - Alarm: `aerowise-t1-nifi-disk-usage`
   - Threshold: 80% for 10 minutes (2 × 5-minute periods)

View alarms:
```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix aerowise-t1-nifi
```

### Application Logs
NiFi logs are in:
```
/opt/nifi/current/logs/
├── nifi-app.log          # Main application log
├── nifi-user.log         # User action audit log
└── nifi-bootstrap.log    # Startup/shutdown events
```

## Security

### Security Group Rules
| Direction | Port | Protocol | Source | Purpose |
|-----------|------|----------|--------|---------|
| Ingress | 8080 | TCP | ALB SG | NiFi Web UI |
| Ingress | 8443 | TCP | ALB SG | NiFi Secure UI |
| Ingress | 6007 | TCP | Self | NiFi Cluster |
| Ingress | 22 | TCP | Your CIDR | SSH |
| Egress | All | All | 0.0.0.0/0 | Outbound |

### IAM Permissions
The NiFi instance has:
- **Snapshot Creation**: Create snapshots of attached volumes
- **CloudWatch**: Send metrics and logs
- **Systems Manager**: EC2 Instance Connect, session logs
- **KMS**: Decrypt EBS volumes

## Troubleshooting

### NiFi Won't Start
1. SSH to instance (via Systems Manager Session Manager)
2. Check service status: `sudo systemctl status nifi`
3. View logs: `tail -f /opt/nifi/current/logs/nifi-app.log`
4. Restart: `sudo systemctl restart nifi`

### Disk Space Issues
1. Check usage: `df -h /nifi_data`
2. View NiFi data: `du -sh /nifi_data/*`
3. Options:
   - Delete old provenance/content
   - Increase volume size (expand gp3 volume)
   - Archive content to S3

### Connection Issues
1. Verify security group: `aws ec2 describe-security-groups --group-ids sg-xxxxx`
2. Test connectivity from another instance:
   ```bash
   telnet <nifi-private-ip> 8080
   ```
3. Check network ACLs and route tables

### Snapshot Failures
1. Check DLM policy status:
   ```bash
   aws dlm get-lifecycle-policy --policy-id policy-xxxxx
   ```
2. Review DLM logs in CloudWatch
3. Verify IAM role has required permissions

## Scaling

### Vertical Scaling (Change Instance Type)
1. Stop instance: `aws ec2 stop-instances --instance-ids i-xxxxx`
2. Change type: `aws ec2 modify-instance-attribute --instance-id i-xxxxx --instance-type m5.4xlarge`
3. Start instance: `aws ec2 start-instances --instance-ids i-xxxxx`
4. Update Terraform variable: `nifi_instance_type = "m5.4xlarge"`
5. Run `terraform apply` to sync state

### Horizontal Scaling (Multiple Instances)
For NiFi clustering:
1. Deploy additional instances with same configuration
2. Configure NiFi cluster in `nifi.properties`
3. Set cluster node to true: `nifi.cluster.is.node=true`
4. Configure cluster manager details
5. Sync flow configuration across nodes

## Costs

### Monthly Cost Estimate (us-east-1)

| Component | Size | Rate | Monthly Cost |
|-----------|------|------|--------------|
| EC2 Instance | m5.2xlarge | $0.384/hr | ~$280 |
| EBS Volume | 128 GB gp3 | $0.10/GB | $12.80 |
| EBS Snapshots | 14 snapshots | $0.08 each | ~$1.12 |
| CloudWatch | Metrics + Alarms | Variable | ~$2 |
| **Total** | | | **~$296/month** |

**Note**: Prices are approximate for us-east-1. Check AWS Pricing Calculator for your region.

## Maintenance

### Regular Tasks

**Weekly**:
- Monitor disk space
- Review NiFi logs for errors
- Check CloudWatch alarms

**Monthly**:
- Verify snapshots are completing
- Review content repository size
- Archive old provenance data

**Quarterly**:
- Test snapshot restoration
- Review security group rules
- Plan capacity needs

### Backup Strategy
1. **Daily Snapshots**: Automatic via DLM (14 days retention)
2. **Archival**: Export flows to S3 for long-term retention
3. **Configuration**: Version control NiFi properties file
4. **Recovery**: Test restore process quarterly

## Terraform Module Files

```
terraform/modules/nifi-ec2/
├── main.tf              # EC2, EBS, DLM, IAM resources
├── variables.tf         # Input variables
├── outputs.tf           # Output values
└── user_data.sh        # Instance initialization script
```

## Cleanup / Destruction

### Remove NiFi Only (Keep Infrastructure)
```bash
# Method 1: Disable creation flag
# Edit terraform.tfvars:
create_nifi_ec2 = false

# Apply:
terraform apply
```

### Remove NiFi and All Infrastructure
```bash
cd terraform/infra
terraform destroy
```

**Warning**: This will delete all infrastructure including RDS, EKS, etc.

## Support & Documentation

- **NiFi Documentation**: https://nifi.apache.org/docs.html
- **AWS EC2**: https://docs.aws.amazon.com/ec2/
- **AWS DLM**: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/snapshot-lifecycle.html
- **Terraform Modules**: See `terraform/modules/nifi-ec2/`
