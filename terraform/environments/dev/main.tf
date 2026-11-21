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

module "jenkins" {
  # Transitional in-VPC bootstrap host. Retire after MySQL migration and Argo CD verification.
  source = "../../modules/jenkins"

  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  public_subnet_id    = module.network.public_subnet_ids[0]
  admin_cidr          = var.admin_cidr
  ssh_public_key_path = var.jenkins_ssh_public_key_path
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

resource "aws_iam_role_policy" "bootstrap_eks_describe" {
  name = "${var.project_name}-bootstrap-eks-describe"
  role = module.jenkins.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = module.eks.cluster_arn
    }]
  })
}

resource "aws_eks_access_entry" "bootstrap" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins.iam_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bootstrap" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins.iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bootstrap]
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_to_eks_api" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.jenkins.security_group_id
  description                  = "Temporary access for in-VPC database migration and Argo CD bootstrap; remove with the bootstrap EC2"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
