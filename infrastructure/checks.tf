resource "terraform_data" "guardrails" {
  input = var.environment

  lifecycle {
    precondition {
      condition = var.environment != "prod" || (
        var.availability_zone_count == 3 &&
        var.single_nat_gateway == false &&
        var.desired_count >= 2 &&
        var.minimum_task_count >= 2 &&
        var.database_multi_az == true &&
        var.database_backup_retention_days >= 7 &&
        var.deletion_protection == true &&
        var.skip_final_snapshot == false &&
        var.use_fargate_spot == false &&
        var.certificate_arn != null &&
        can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/", var.certificate_arn)) &&
        can(regex("@sha256:[0-9a-f]{64}$", var.container_image))
      )
      error_message = "Production requires 3 AZs, one NAT per AZ, >=2 tasks, Multi-AZ RDS, >=7-day backups, deletion protection, final snapshots, on-demand Fargate, a valid ACM certificate ARN, and an immutable sha256 image digest."
    }

    precondition {
      condition     = var.minimum_task_count <= var.desired_count && var.desired_count <= var.maximum_task_count
      error_message = "Task counts must satisfy minimum <= desired <= maximum."
    }
  }
}
