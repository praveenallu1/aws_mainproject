resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = aws_subnet.database[*].id
  tags       = { Name = local.name }
}

resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${local.name}-"
  family      = "postgres16"
  description = "PostgreSQL parameters for ${local.name}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "rds_postgresql" {
  name              = "/aws/rds/instance/${local.name}/postgresql"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "rds_upgrade" {
  name              = "/aws/rds/instance/${local.name}/upgrade"
  retention_in_days = var.log_retention_days
}

resource "aws_db_instance" "main" {
  identifier = local.name

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.database_instance_class

  db_name  = var.database_name
  username = var.database_username
  port     = 5432

  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.workload.arn

  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = var.database_max_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.workload.arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = var.database_multi_az

  parameter_group_name = aws_db_parameter_group.postgres.name

  backup_retention_period = var.database_backup_retention_days
  backup_window           = "14:00-14:30"
  maintenance_window      = "sun:15:00-sun:16:00"
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade      = true
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.workload.arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name}-final-${formatdate(
    "YYYYMMDDhhmmss",
    timestamp()
  )}"

  apply_immediately = var.environment != "prod"

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }

  depends_on = [
    aws_cloudwatch_log_group.rds_postgresql,
    aws_cloudwatch_log_group.rds_upgrade
  ]
}

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
