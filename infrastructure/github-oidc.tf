locals {
  github_oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_deploy_assume" {
  count = var.create_github_deploy_role && var.github_repository != null ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        local.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  count = var.create_github_deploy_role && var.github_repository != null ? 1 : 0

  name                 = "${local.name}-github-app-deploy"
  description          = "Deploys immutable API images from the protected ${var.environment} GitHub environment"
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_assume[0].json
  max_session_duration = 3600

  depends_on = [aws_iam_openid_connect_provider.github]
}

data "aws_iam_policy_document" "github_deploy" {
  count = var.create_github_deploy_role && var.github_repository != null ? 1 : 0

  statement {
    sid       = "ECRLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushApplicationImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid    = "DeployECSRevision"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "PassOnlyWorkloadRolesToECS"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_execution.arn,
      aws_iam_role.ecs_task.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  count = var.create_github_deploy_role && var.github_repository != null ? 1 : 0

  name   = "deploy-cloudops-api"
  role   = aws_iam_role.github_deploy[0].id
  policy = data.aws_iam_policy_document.github_deploy[0].json
}
