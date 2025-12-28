########################################
# CALICO (POLICY-ONLY FOR EKS)
########################################

resource "kubernetes_namespace" "calico" {
  metadata {
    name = "calico-system"
  }
}

resource "helm_release" "calico" {
  name       = "calico"
  repository = "https://projectcalico.docs.tigera.io/charts"
  chart      = "tigera-operator"
  namespace  = kubernetes_namespace.calico.metadata[0].name
  version    = "v3.27.3"

  # Configurable wait/timeout/hooks to speed up dev workflows when needed
  wait    = var.helm_wait
  timeout = var.helm_timeout

  set {
    name  = "installation.kubernetesProvider"
    value = "EKS"
  }

  set {
    name  = "installation.calicoNetwork.provider"
    value = "AmazonVPC"
  }

  set {
    name  = "installation.calicoNetwork.mode"
    value = "Policy"
  }

  set {
    name  = "installation.calicoNetwork.bgp"
    value = "Disabled"
  }
}


########################################
# APPLICATION NAMESPACE
########################################

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}

########################################
# ALLOW HTTPS EGRESS (AWS APIS, ECR, ETC)
########################################

resource "kubernetes_network_policy" "allow_https_egress" {
  metadata {
    name      = "allow-https-egress"
    namespace = var.app_namespace
  }

  spec {
    pod_selector {}

    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = 443
      }
    }

    policy_types = ["Egress"]
  }

  depends_on = [
    kubernetes_namespace.app,
    helm_release.calico
  ]
}

########################################
# ALLOW VPC / ALB / API-GW → APP
########################################

resource "kubernetes_network_policy" "allow_vpc_to_app" {
  metadata {
    name      = "allow-vpc-to-app"
    namespace = var.app_namespace
  }

  spec {
    pod_selector {}

    ingress {
      from {
        ip_block {
          cidr = "10.0.0.0/16"
        }
      }

      ports {
        protocol = "TCP"
        port     = var.app_port
      }
    }

    policy_types = ["Ingress"]
  }

  depends_on = [
    kubernetes_namespace.app,
    helm_release.calico
  ]
}

########################################
# ALLOW APP → DATABASE
########################################

resource "kubernetes_network_policy" "allow_app_to_db" {
  metadata {
    name      = "allow-app-to-db"
    namespace = var.app_namespace
  }

  spec {
    pod_selector {}

    egress {
      to {
        ip_block {
          cidr = var.db_subnet_cidr
        }
      }

      ports {
        protocol = "TCP"
        port     = 5432
      }
    }

    policy_types = ["Egress"]
  }

  depends_on = [
    kubernetes_namespace.app,
    helm_release.calico
  ]
}

########################################
# ALLOW DNS (UDP + TCP)
########################################

resource "kubernetes_network_policy" "allow_dns" {
  metadata {
    name      = "allow-dns"
    namespace = var.app_namespace
  }

  spec {
    pod_selector {}

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }

      ports {
        protocol = "UDP"
        port     = 53
      }

      ports {
        protocol = "TCP"
        port     = 53
      }
    }

    policy_types = ["Egress"]
  }

  depends_on = [
    kubernetes_namespace.app,
    helm_release.calico
  ]
}
