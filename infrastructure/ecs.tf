resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${local.name}/cloudops-api"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT"
  ]

  default_capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 100
    base              = var.use_fargate_spot ? 0 : 1
  }
}

resource "aws_lb" "app" {
  name                       = substr(local.name, 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
  enable_http2               = true

  access_logs {
    bucket  = aws_s3_bucket.access_logs.id
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.access_logs]
}

resource "aws_lb_target_group" "app" {
  name        = substr("${local.name}-api", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http_forward" {
  count = local.https_enabled ? 0 : 1

  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    sid     = "ReadDatabaseCredentials"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      local.database_secret_arn
    ]
  }

  statement {
    sid     = "DecryptDatabaseCredentials"
    effect  = "Allow"
    actions = ["kms:Decrypt"]
    resources = [
      aws_kms_key.workload.arn
    ]
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "read-database-secret"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    sid    = "ECSExecChannels"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-cloudops-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "cloudops-api"
      image     = var.container_image
      essential = true

      portMappings = [{
        name          = "http"
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "APP_VERSION", value = var.container_image },
        { name = "PORT", value = tostring(var.container_port) },
        { name = "LOG_LEVEL", value = "info" },
        { name = "DB_REQUIRED", value = "true" },
        { name = "DB_HOST", value = aws_db_instance.main.address },
        { name = "DB_PORT", value = tostring(aws_db_instance.main.port) },
        { name = "DB_NAME", value = var.database_name },
        { name = "DB_SSL", value = "true" },
        { name = "NODE_EXTRA_CA_CERTS", value = "/app/certs/global-bundle.pem" }
      ]

      secrets = [
        { name = "DB_USER", valueFrom = "${local.database_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${local.database_secret_arn}:password::" }
      ]

      readonlyRootFilesystem = true
      stopTimeout            = 30

      linuxParameters = {
        initProcessEnabled = true
        capabilities = {
          drop = ["ALL"]
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"fetch('http://127.0.0.1:${var.container_port}/health/live').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "cloudops-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count

  enable_execute_command             = true
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    assign_public_ip = false
    subnets          = aws_subnet.application[*].id
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "cloudops-api"
    container_port   = var.container_port
  }

  dynamic "capacity_provider_strategy" {
    for_each = [var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"]
    content {
      capacity_provider = capacity_provider_strategy.value
      weight            = 100
      base              = var.use_fargate_spot ? 0 : 1
    }
  }

  lifecycle {
    # Application revisions and autoscaled desired count are owned by their
    # respective control loops after Terraform creates the service.
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [
    aws_lb_listener.http_forward,
    aws_lb_listener.https,
    aws_iam_role_policy.ecs_execution_secrets
  ]
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.maximum_task_count
  min_capacity       = var.minimum_task_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${local.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "${local.name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
