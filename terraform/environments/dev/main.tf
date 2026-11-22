module "network" {
  source = "../../modules/network"

  project_name = var.project_name
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = "${var.project_name}-eks"
  kubernetes_version = var.kubernetes_version
  private_subnet_ids = module.network.private_subnet_ids
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

moved {
  from = aws_iam_role.github_actions_deploy
  to   = aws_iam_role.github_actions_ci
}

moved {
  from = aws_iam_role_policy.github_actions_deploy
  to   = aws_iam_role_policy.github_actions_ci
}

locals {
  github_repository_parts = split("/", var.github_repository)
  github_oidc_subject     = "repo:${local.github_repository_parts[0]}@${var.github_repository_owner_id}/${local.github_repository_parts[1]}@${var.github_repository_id}:ref:refs/heads/main"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_oidc_subject]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  # Keep the existing AWS role ARN so the GitHub AWS_ROLE_ARN variable remains valid.
  name               = "${var.project_name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "aws_iam_role_policy" "github_actions_ci" {
  name = "${var.project_name}-github-actions-deploy"
  role = aws_iam_role.github_actions_ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = values(module.ecr.repository_arns)
      }
    ]
  })
}
