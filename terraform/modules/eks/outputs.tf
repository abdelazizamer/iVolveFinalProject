output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Private Kubernetes API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.workers.node_group_name
}
