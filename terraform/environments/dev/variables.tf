variable "aws_region" {
  description = "AWS region for the development environment"
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "Prefix used for project resource names"
  type        = string
  default     = "ivolve-devops"
}
variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}
variable "admin_cidr" {
  description = "Your public IPv4 CIDR, restricted to your address"
  type        = string
}

variable "jenkins_ssh_public_key_path" {
  description = "Absolute path to your SSH public key file"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy to EKS, in owner/name format"
  type        = string
  default     = "abdelazizamer/iVolveFinalProject"
}

variable "github_repository_owner_id" {
  description = "Immutable GitHub owner ID used in the OIDC subject claim"
  type        = string
  default     = "143232543"
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in the OIDC subject claim"
  type        = string
  default     = "1464475006"
}
