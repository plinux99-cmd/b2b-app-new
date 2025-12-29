data "aws_caller_identity" "current" {}

resource "aws_secretsmanager_secret" "db_credentials" {
  count                   = var.create_secrets ? 1 : 0
  name                    = "${var.project_name}-db-credentials-${random_string.secret_suffix[0].result}"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = false #temp
  }

  tags = var.tags
}

resource "random_string" "secret_suffix" {
  count   = var.create_secrets ? 1 : 0
  length  = 6
  special = false
  upper   = false
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = var.create_secrets ? aws_secretsmanager_secret.db_credentials[0].id : var.secret_arn

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    dbname   = var.db_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

// secret_arn output is defined in outputs.tf (uses conditional to prefer created secret)

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "Allow PostgreSQL access from EKS worker nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  lifecycle {
    prevent_destroy = false #temp
    ignore_changes  = [subnet_ids]
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  iops              = var.storage_type == "gp3" ? var.iops : null
  storage_throughput = var.storage_type == "gp3" ? var.storage_throughput : null
  
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  performance_insights_enabled = true
  backup_retention_period      = 7
  storage_encrypted            = true
  multi_az                     = true

  deletion_protection       = false                                         #temp
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-postgres-final-snapshot"
  lifecycle {
    prevent_destroy = false #temp
  }

  tags = var.tags
}
