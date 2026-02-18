variable "argocd_admin_password_bcrypt" {
  description = "Bcrypt hash of the ArgoCD admin password (set via Helm to avoid ESO annotation propagation). Generate: python3 -c \"import bcrypt; print(bcrypt.hashpw(b'PASSWORD', bcrypt.gensalt(10)).decode())\""
  type        = string
  sensitive   = true
}

variable "argocd_repo_ssh_private_key" {
  description = "SSH private key for the ArgoCD deploy key (read-only access to the homelab repo)"
  type        = string
  sensitive   = true
}

variable "kube_context" {
  description = "kubeconfig context to use (e.g. orbstack for OrbStack)"
  type        = string
  default     = "orbstack"
}

variable "argocd_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "7.8.0"
}

variable "homelab_repo_url" {
  description = "Git repository SSH URL for the homelab GitOps source"
  type        = string
  default     = "git@github.com:holdennguyen/homelab.git"
}

# ── Infisical bootstrap secrets ───────────────────────────────────────────────
# These are the ONLY secrets Infisical cannot provide itself (chicken-and-egg).
# Generate with: openssl rand -hex 16 (ENCRYPTION_KEY) and
#                openssl rand -base64 32 (AUTH_SECRET)

variable "infisical_encryption_key" {
  description = "Infisical ENCRYPTION_KEY (32-char hex)"
  type        = string
  sensitive   = true
}

variable "infisical_auth_secret" {
  description = "Infisical AUTH_SECRET (base64-encoded random string)"
  type        = string
  sensitive   = true
}

# ── Infisical internal database & cache ───────────────────────────────────────
# Credentials for the PostgreSQL and Redis bundled inside the Infisical Helm chart.

variable "infisical_postgres_password" {
  description = "Password for Infisical's internal PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "infisical_redis_password" {
  description = "Password for Infisical's internal Redis instance"
  type        = string
  sensitive   = true
}

# ── External Secrets Operator machine identity ────────────────────────────────
# Create a Machine Identity in the Infisical UI:
#   Settings → Machine Identities → Create → Universal Auth
# Paste the resulting clientId and clientSecret here.
# These can be rotated to Infisical-managed once Infisical is running.

variable "infisical_machine_identity_client_id" {
  description = "Infisical Machine Identity clientId for ESO"
  type        = string
  sensitive   = true
}

variable "infisical_machine_identity_client_secret" {
  description = "Infisical Machine Identity clientSecret for ESO"
  type        = string
  sensitive   = true
}
