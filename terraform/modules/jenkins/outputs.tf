output "instance_id" {
  value = aws_instance.jenkins.id
}

output "public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "iam_role_arn" {
  value = aws_iam_role.jenkins.arn
}

output "iam_role_name" {
  description = "Name of the Jenkins EC2 instance role"
  value       = aws_iam_role.jenkins.name
}

output "security_group_id" {
  description = "Security group attached to the Jenkins EC2 instance"
  value       = aws_security_group.jenkins.id
}
