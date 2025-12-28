output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS worker node security group ID"
  value       = aws_security_group.nodes.id
}

# NOTE: `cluster_security_group_id` is the EKS control-plane security group.
# The worker node security group is exported separately above as
# `node_security_group_id` to be consumed by other modules (VPC endpoints, RDS
# access, etc.). Previously this output mistakenly returned the control-plane
# SG which could prevent worker nodes from reaching required VPC endpoints.


output "eks_cluster_role_arn" {
  description = "EKS Cluster Role ARN"
  value       = aws_iam_role.cluster.arn
}
output "cluster_ready" {
  description = "EKS cluster + core addons ready"
  value = [
    aws_eks_cluster.this,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns
  ]
}
output "oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

