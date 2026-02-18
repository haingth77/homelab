# ── Namespace pre-creation ────────────────────────────────────────────────────
# These namespaces must exist before ArgoCD syncs the child Applications,
# because the secrets below are created here and referenced by those apps.

resource "kubernetes_namespace" "infisical" {
  metadata {
    name = "infisical"
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

# ── infisical/infisical-secrets ───────────────────────────────────────────────
# Infisical reads ENCRYPTION_KEY and AUTH_SECRET from this secret on startup.
# It cannot come from Infisical itself (chicken-and-egg), so Terraform owns it.

resource "kubernetes_secret" "infisical_bootstrap" {
  metadata {
    name      = "infisical-secrets"
    namespace = kubernetes_namespace.infisical.metadata[0].name
  }

  data = {
    ENCRYPTION_KEY = var.infisical_encryption_key
    AUTH_SECRET    = var.infisical_auth_secret
  }

  type = "Opaque"
}

# ── argocd/infisical-helm-secrets ─────────────────────────────────────────────
# The ArgoCD Application for Infisical uses `valuesFrom` to inject the
# postgres and redis passwords without storing them in git.
# The value must be a YAML string matching the Helm chart's values schema.

resource "kubernetes_secret" "infisical_helm_secrets" {
  metadata {
    name      = "infisical-helm-secrets"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "values.yaml" = yamlencode({
      postgresql = {
        auth = {
          password = var.infisical_postgres_password
        }
      }
      redis = {
        auth = {
          password = var.infisical_redis_password
        }
      }
    })
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.argocd]
}

# ── external-secrets/infisical-machine-identity ───────────────────────────────
# External Secrets Operator uses this Universal Auth credential to authenticate
# against Infisical and pull secrets into the cluster.
# After Infisical is running, create a new Machine Identity in the Infisical UI
# and update this via `terraform apply` to rotate away from the bootstrap value.

resource "kubernetes_secret" "infisical_machine_identity" {
  metadata {
    name      = "infisical-machine-identity"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }

  data = {
    clientId     = var.infisical_machine_identity_client_id
    clientSecret = var.infisical_machine_identity_client_secret
  }

  type = "Opaque"
}
