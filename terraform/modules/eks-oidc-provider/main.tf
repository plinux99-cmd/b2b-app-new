data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Extract the OIDC issuer URL from the cluster
locals {
  oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  # Remove the https:// prefix to get the issuer hostname
  oidc_issuer_hostname = replace(local.oidc_issuer_url, "https://", "")
}

# Create OIDC provider
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = local.oidc_issuer_url

  tags = {
    Name        = "${var.cluster_name}-oidc-provider"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Get the thumbprint for OIDC provider verification
data "tls_certificate" "cluster" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}
