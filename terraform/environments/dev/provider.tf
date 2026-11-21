provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "CloudDevOpsProject"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
