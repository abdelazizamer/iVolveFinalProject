variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "admin_cidr" {
  description = "Your public IPv4 CIDR, for example x.x.x.x/32"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key; never use the private key here"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

