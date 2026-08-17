locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Repository  = var.repository_url
  }, var.additional_tags)

  nat_gateway_count = var.single_nat_gateway ? 1 : var.availability_zone_count
  https_enabled     = var.certificate_arn != null
  database_secret_arn = try(
    aws_db_instance.main.master_user_secret[0].secret_arn,
    null
  )
}

