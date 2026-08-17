output "application_url" {
  description = "ALB endpoint. Use the configured DNS name when a certificate is supplied."
  value       = "${local.https_enabled ? "https" : "http"}://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "database_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "database_secret_arn" {
  value     = local.database_secret_arn
  sensitive = true
}

output "cloudwatch_dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alarm_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "github_app_deploy_role_arn" {
  value = try(aws_iam_role.github_deploy[0].arn, null)
}

output "private_subnet_ids" {
  value = aws_subnet.application[*].id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

