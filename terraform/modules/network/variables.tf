variable "project_name" {
  description = "Short project prefix for AWS resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the project VPC"
  type        = string
  default     = "10.20.0.0/16"
}
