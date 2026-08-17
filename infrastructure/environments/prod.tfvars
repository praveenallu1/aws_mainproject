environment = "prod"
owner       = "REPLACE_WITH_YOUR_NAME"

aws_region              = "ap-southeast-2"
availability_zone_count = 3
single_nat_gateway      = false
enable_vpc_endpoints    = true

desired_count      = 2
minimum_task_count = 2
maximum_task_count = 10
task_cpu           = 1024
task_memory        = 2048
use_fargate_spot   = false

database_instance_class        = "db.t4g.small"
database_multi_az              = true
database_backup_retention_days = 14
deletion_protection            = true
skip_final_snapshot            = false

log_retention_days = 90
monthly_budget_usd = 250

# Required before a production plan succeeds:
certificate_arn = "REPLACE_WITH_ACM_CERTIFICATE_ARN"
container_image = "REPLACE_WITH_IMMUTABLE_ECR_IMAGE_DIGEST"

# Recommended after creating the protected GitHub production environment:
# repository_url              = "https://github.com/OWNER/REPOSITORY"
# github_repository           = "OWNER/REPOSITORY"
# create_github_deploy_role   = true
