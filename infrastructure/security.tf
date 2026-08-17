resource "aws_kms_key" "workload" {
  description             = "Encrypts ${local.name} workload data"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "workload" {
  name          = "alias/${local.name}-workload"
  target_key_id = aws_kms_key.workload.key_id
}

resource "aws_security_group" "alb" {
  name_prefix            = "${local.name}-alb-"
  description            = "Public entry point for ${local.name}"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = { Name = "${local.name}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP entry point or HTTPS redirect"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = local.https_enabled ? 1 : 0

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS public entry point"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_security_group" "ecs" {
  name_prefix            = "${local.name}-ecs-"
  description            = "Fargate tasks for ${local.name}"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = { Name = "${local.name}-ecs" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Application traffic from the ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward traffic only to ECS tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "database" {
  name_prefix            = "${local.name}-db-"
  description            = "PostgreSQL database for ${local.name}"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = { Name = "${local.name}-db" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_ecs" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL only from application tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_database" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "PostgreSQL to the database tier"
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "TLS egress for AWS APIs and explicitly used external APIs"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_dns_udp" {
  security_group_id = aws_security_group.ecs.id
  description       = "DNS through the VPC resolver"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_dns_tcp" {
  security_group_id = aws_security_group.ecs.id
  description       = "DNS fallback through the VPC resolver"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix            = "${local.name}-endpoints-"
  description            = "Private AWS API endpoints for ${local.name}"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = { Name = "${local.name}-endpoints" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_ecs" {
  security_group_id            = aws_security_group.vpc_endpoints.id
  description                  = "TLS from ECS tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

