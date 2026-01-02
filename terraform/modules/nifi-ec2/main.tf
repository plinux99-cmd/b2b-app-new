# NiFi EC2 Instance Module
# Creates an m5.2xlarge EC2 instance for Apache NiFi with 128GB storage and snapshot enabled

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Security Group for NiFi EC2
resource "aws_security_group" "nifi" {
  name_prefix = "${var.project_name}-nifi-"
  description = "Security group for NiFi EC2 instance"
  vpc_id      = var.vpc_id

  # Inbound: HTTP (NiFi UI)
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "NiFi Web UI from ALB"
  }

  # Inbound: HTTPS (NiFi UI)
  ingress {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "NiFi Secure Web UI from ALB"
  }

  # Inbound: Cluster communication
  ingress {
    from_port   = 6007
    to_port     = 6007
    protocol    = "tcp"
    self        = true
    description = "NiFi Cluster communication"
  }

  # Inbound: SSH (restricted to specific IPs)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
    description = "SSH access"
  }

  # Outbound: All traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nifi-sg"
    }
  )
}

# IAM Role for NiFi EC2 instance
resource "aws_iam_role" "nifi" {
  name_prefix = "${var.project_name}-nifi-"
  description = "IAM role for NiFi EC2 instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nifi-role"
    }
  )
}

# IAM Policy for EBS snapshot permissions
resource "aws_iam_role_policy" "nifi_snapshots" {
  name_prefix = "${var.project_name}-nifi-snapshots-"
  role        = aws_iam_role.nifi.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshotAttribute",
          "ec2:ModifySnapshotAttribute"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*::snapshot/*"
      }
    ]
  })
}

# IAM Policy for CloudWatch and Systems Manager
resource "aws_iam_role_policy_attachment" "nifi_cloudwatch" {
  role       = aws_iam_role.nifi.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "nifi_ssm" {
  role       = aws_iam_role.nifi.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "nifi" {
  name_prefix = "${var.project_name}-nifi-"
  role        = aws_iam_role.nifi.name
}

# EC2 Instance for NiFi
resource "aws_instance" "nifi" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.nifi.name
  vpc_security_group_ids = [aws_security_group.nifi.id]
  subnet_id              = var.subnet_id

  # Root volume - use 128GB for all NiFi data
  root_block_device {
    volume_size           = var.storage_size
    volume_type           = var.ebs_volume_type
    delete_on_termination = true
    encrypted             = var.ebs_encryption_enabled
    kms_key_id            = var.kms_key_id

    tags = {
      Name = "${var.project_name}-nifi-root"
    }
  }

  monitoring = true
  associate_public_ip_address = var.associate_public_ip

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    PROJECT_NAME            = var.project_name
    NIFI_VERSION            = var.nifi_version
    DEVICE_NAME             = var.ebs_device_name
    ENABLE_KEYCLOAK         = var.enable_keycloak_auth ? "true" : "false"
    KEYCLOAK_URL            = var.keycloak_url
    KEYCLOAK_REALM          = var.keycloak_realm
    KEYCLOAK_CLIENT_ID      = var.keycloak_client_id
    KEYCLOAK_CLIENT_SECRET  = var.keycloak_client_secret
    NIFI_ADMIN_IDENTITY     = var.nifi_admin_identity
  }))

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nifi"
    }
  )

  depends_on = [aws_iam_instance_profile.nifi]
}

# Data Lifecycle Manager for automatic snapshots
resource "aws_dlm_lifecycle_policy" "nifi_snapshots" {
  description        = "Daily snapshot policy for NiFi data volume"
  execution_role_arn = aws_iam_role.dlm.arn
  state               = "ENABLED"
  policy_details {
    policy_type = "EBS_SNAPSHOT_MANAGEMENT"
    resource_types = ["VOLUME"]
    schedule {
      name = "Daily Snapshots"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }
      retain_rule {
        count = var.snapshot_retention_count
      }
      tags_to_add = merge(
        var.tags,
        {
          Name        = "${var.project_name}-nifi-snapshot"
          ManagedBy   = "DataLifecycleManager"
        }
      )
      copy_tags = true
    }
    target_tags = {
      SnapshotEnabled = "true"
    }
  }
}

# IAM Role for Data Lifecycle Manager
resource "aws_iam_role" "dlm" {
  name_prefix = "${var.project_name}-dlm-"
  description = "IAM role for DLM snapshots"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dlm_default" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

# Tag the root volume for automatic snapshots
resource "aws_ec2_tag" "nifi_volume_snapshot_tag" {
  resource_id = aws_instance.nifi.root_block_device[0].volume_id
  key         = "SnapshotEnabled"
  value       = "true"
}

# CloudWatch Alarms for NiFi instance
resource "aws_cloudwatch_metric_alarm" "nifi_instance_status" {
  alarm_name          = "${var.project_name}-nifi-instance-status"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alert when NiFi instance status check fails"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.nifi.id
  }
}

resource "aws_cloudwatch_metric_alarm" "nifi_disk_usage" {
  alarm_name          = "${var.project_name}-nifi-disk-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when NiFi disk usage is above 80%"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.nifi.id
    device     = var.ebs_device_name
  }
}
