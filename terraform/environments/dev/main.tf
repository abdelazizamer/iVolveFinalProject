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
  source = "../../modules/jenkins"

  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  public_subnet_id    = module.network.public_subnet_ids[0]
  admin_cidr          = var.admin_cidr
  ssh_public_key_path = var.jenkins_ssh_public_key_path
}

resource "aws_iam_role_policy" "jenkins_ecr_push" {
  name = "${var.project_name}-jenkins-ecr-push"
  role = module.jenkins.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage"
        ]
        Resource = values(module.ecr.repository_arns)
      }
    ]
  })
}
