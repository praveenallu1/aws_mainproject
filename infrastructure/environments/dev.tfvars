environment = "dev"
owner       = "REPLACE_WITH_YOUR_NAME"

aws_region              = "ap-southeast-2"
availability_zone_count = 2
single_nat_gateway      = true
enable_vpc_endpoints    = false

desired_count      = 1
minimum_task_count = 1
maximum_task_count = 3
task_cpu           = 512
task_memory        = 1024
use_fargate_spot   = true

database_instance_class        = "db.t4g.micro"
database_multi_az              = false
database_backup_retention_days = 3
deletion_protection            = false
skip_final_snapshot            = true

log_retention_days = 14
monthly_budget_usd = 50

# Add after the bootstrap image is pushed:
# container_image = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/cloudops-capstone-dev/cloudops-api@sha256:..."

# Add for a real domain and HTTPS:
# certificate_arn = "arn:aws:acm:ap-southeast-2:123456789012:certificate/..."

# Add after creating GitHub environments named dev and prod:
# repository_url                  = "https://github.com/OWNER/REPOSITORY"
# github_repository               = "OWNER/REPOSITORY"
# create_github_oidc_provider     = true  # once per AWS account only
# create_github_deploy_role       = true

