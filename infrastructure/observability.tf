resource "aws_sns_topic" "alarms" {
  name              = "${local.name}-alarms"
  kms_master_key_id = "alias/aws/sns"
}

data "aws_iam_policy_document" "alarms_topic" {
  statement {
    sid    = "AccountManagement"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions   = ["sns:*"]
    resources = [aws_sns_topic.alarms.arn]
  }

  statement {
    sid    = "CloudWatchPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "EventBridgePublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alarms" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.alarms_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  alarm_description   = "ALB is returning server errors; inspect target health and application logs."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  period              = 60
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = { LoadBalancer = aws_lb.app.arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${local.name}-unhealthy-targets"
  alarm_description   = "One or more API targets are unhealthy."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  period              = 60
  statistic           = "Maximum"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${local.name}-ecs-high-cpu"
  alarm_description   = "ECS CPU is above 85% despite target tracking."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  evaluation_periods  = 3
  period              = 300
  statistic           = "Average"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-high-cpu"
  alarm_description   = "RDS CPU pressure is sustained above 80%."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  evaluation_periods  = 3
  period              = 300
  statistic           = "Average"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name}-rds-low-storage"
  alarm_description   = "RDS has less than 5 GiB free; validate storage autoscaling and growth."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  comparison_operator = "LessThanThreshold"
  threshold           = 5368709120
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.identifier }
}

resource "aws_cloudwatch_event_rule" "ecs_deployment_failed" {
  name        = "${local.name}-ecs-deployment-failed"
  description = "Notify operators when the ECS deployment circuit breaker fails a release"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Deployment State Change"]
    detail = {
      eventName = ["SERVICE_DEPLOYMENT_FAILED"]
      clusterArn = [
        aws_ecs_cluster.main.arn
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_deployment_failed" {
  rule      = aws_cloudwatch_event_rule.ecs_deployment_failed.name
  target_id = "alarm-topic"
  arn       = aws_sns_topic.alarms.arn
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API requests and latency"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum" }],
            [".", "TargetResponseTime", ".", ".", { stat = "p95", yAxis = "right" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Target health and errors"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS utilization"
          region = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.app.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS health"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", ".", { yAxis = "right" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Recent application errors"
          region = var.aws_region
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, level, msg, err.message | filter level >= 50 | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}

resource "aws_budgets_budget" "monthly" {
  count = var.monthly_budget_usd != null && var.alarm_email != null ? 1 : 0

  name         = "${local.name}-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alarm_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alarm_email]
  }
}
