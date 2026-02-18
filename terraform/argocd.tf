resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version

  # Expose argocd-server via NodePort so tailscale serve can proxy it.
  set {
    name  = "server.service.type"
    value = "NodePort"
  }
  set {
    name  = "server.service.nodePorts.http"
    value = "30080"
  }
  set {
    name  = "server.service.nodePorts.https"
    value = "30443"
  }

  # Run server without TLS so the NodePort plain-HTTP path works for tailscale serve.
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Reduce resource footprint for a single-node homelab.
  set {
    name  = "applicationSet.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "notifications.resources.requests.memory"
    value = "32Mi"
  }
  set {
    name  = "redis.resources.requests.memory"
    value = "32Mi"
  }

  depends_on = [kubernetes_namespace.argocd]
}

# ── Root Application (App of Apps) ─────────────────────────────────────────────
# We use null_resource + local-exec instead of kubernetes_manifest because
# kubernetes_manifest validates the schema against the live API at plan time,
# and the Application CRD is only available after the Helm release above runs.
# Writing to a local file and applying with kubectl sidesteps that ordering issue.

locals {
  argocd_root_app_yaml = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "argocd-apps"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.homelab_repo_url
        targetRevision = "HEAD"
        path           = "k8s/apps/argocd"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["ServerSideApply=true"]
      }
    }
  })
}

# Rendered to a local file so kubectl can read it cleanly (avoids shell quoting issues).
resource "local_file" "argocd_root_app" {
  filename        = "${path.module}/.argocd-root-app.yaml"
  content         = local.argocd_root_app_yaml
  file_permission = "0600"
}

resource "null_resource" "argocd_root_app" {
  triggers = {
    manifest = local.argocd_root_app_yaml
  }

  provisioner "local-exec" {
    command = "kubectl apply --server-side -f '${local_file.argocd_root_app.filename}'"
  }

  depends_on = [helm_release.argocd, local_file.argocd_root_app]
}
