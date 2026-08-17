resource "aws_wafv2_web_acl" "app" {
  name        = local.name
  description = "Managed edge protections for ${local.name}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-common-rule-set"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-ip-reputation"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "per-ip-rate-limit"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = 1000
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "app" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.app.arn
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_wafv2_web_acl_logging_configuration" "app" {
  resource_arn            = aws_wafv2_web_acl.app.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}

