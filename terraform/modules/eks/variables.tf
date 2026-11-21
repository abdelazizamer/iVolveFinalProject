variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "private_subnet_ids" {
  description = "Private subnets for the EKS control plane and worker nodes"
  type        = list(string)
}

variable "worker_instance_type" {
  description = "EC2 instance type for each EKS worker"
  type        = string
  default     = "t3.small"
}

