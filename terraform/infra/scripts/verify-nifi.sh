#!/bin/bash

# NiFi Verification Script
# Validates NiFi EC2 instance and health status

set -e

PROJECT_NAME="${1:-aerowise-t1}"
AWS_REGION="${2:-us-east-1}"

echo "================================================"
echo "NiFi EC2 Instance Verification Script"
echo "================================================"
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo ""

# Get NiFi instance details from Terraform outputs
echo "[1/6] Fetching NiFi instance details..."
INSTANCE_ID=$(terraform output -raw nifi_instance_id 2>/dev/null || echo "")
PRIVATE_IP=$(terraform output -raw nifi_instance_private_ip 2>/dev/null || echo "")
EBS_VOLUME=$(terraform output -raw nifi_ebs_volume_id 2>/dev/null || echo "")
SG_ID=$(terraform output -raw nifi_security_group_id 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "none" ]; then
  echo "❌ NiFi instance not found. Make sure it has been deployed."
  exit 1
fi

echo "✅ Instance ID: $INSTANCE_ID"
echo "✅ Private IP: $PRIVATE_IP"
echo "✅ EBS Volume: $EBS_VOLUME"
echo "✅ Security Group: $SG_ID"
echo ""

# Check instance status
echo "[2/6] Checking instance status..."
STATUS=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)

if [ "$STATUS" = "running" ]; then
  echo "✅ Instance Status: $STATUS"
else
  echo "⚠️  Instance Status: $STATUS (Expected: running)"
fi
echo ""

# Check instance health
echo "[3/6] Checking instance health..."
HEALTH=$(aws ec2 describe-instance-status \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'InstanceStatuses[0].InstanceStatus.Status' \
  --output text 2>/dev/null || echo "initializing")

if [ "$HEALTH" = "ok" ]; then
  echo "✅ Instance Health: $HEALTH"
elif [ "$HEALTH" = "initializing" ]; then
  echo "⏳ Instance Health: initializing (may take a few minutes)"
else
  echo "⚠️  Instance Health: $HEALTH"
fi
echo ""

# Check EBS volume status
echo "[4/6] Checking EBS volume..."
VOL_STATUS=$(aws ec2 describe-volumes \
  --volume-ids "$EBS_VOLUME" \
  --region "$AWS_REGION" \
  --query 'Volumes[0].State' \
  --output text)

VOL_SIZE=$(aws ec2 describe-volumes \
  --volume-ids "$EBS_VOLUME" \
  --region "$AWS_REGION" \
  --query 'Volumes[0].Size' \
  --output text)

if [ "$VOL_STATUS" = "in-use" ]; then
  echo "✅ EBS Volume Status: $VOL_STATUS"
  echo "✅ EBS Volume Size: ${VOL_SIZE} GB"
else
  echo "⚠️  EBS Volume Status: $VOL_STATUS"
fi
echo ""

# Check security group
echo "[5/6] Checking security group rules..."
INGRESS_COUNT=$(aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].IpPermissions | length(@)' \
  --output text)

echo "✅ Ingress Rules: $INGRESS_COUNT"

# Show specific rules
echo "   Port 8080 (HTTP NiFi UI): "
aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`8080`]' \
  --output table || echo "   Not found"

echo ""

# Check CloudWatch alarms
echo "[6/6] Checking CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "$PROJECT_NAME-nifi" \
  --region "$AWS_REGION" \
  --query 'MetricAlarms[*].{Name:AlarmName, State:StateValue}' \
  --output table)

if [ -n "$ALARMS" ]; then
  echo "✅ CloudWatch Alarms:"
  echo "$ALARMS"
else
  echo "⚠️  No CloudWatch alarms found"
fi
echo ""

# Summary
echo "================================================"
echo "Verification Summary"
echo "================================================"
echo "Instance ID:        $INSTANCE_ID"
echo "Private IP:         $PRIVATE_IP"
echo "Instance Status:    $STATUS"
echo "Instance Health:    $HEALTH"
echo "EBS Volume Size:    ${VOL_SIZE} GB"
echo "EBS Volume Status:  $VOL_STATUS"
echo "Security Group:     $SG_ID"
echo ""
echo "Next Steps:"
echo "1. SSH to instance via Systems Manager Session Manager"
echo "   aws ssm start-session --target $INSTANCE_ID --region $AWS_REGION"
echo ""
echo "2. Check NiFi service status:"
echo "   sudo systemctl status nifi"
echo ""
echo "3. Access NiFi Web UI (from within VPC):"
echo "   http://$PRIVATE_IP:8080/nifi"
echo ""
echo "4. View NiFi logs:"
echo "   sudo tail -f /opt/nifi/current/logs/nifi-app.log"
echo ""
echo "5. Check disk usage:"
echo "   df -h /nifi_data"
echo ""
echo "================================================"
