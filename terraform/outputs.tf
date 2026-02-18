output "argocd_url_tailscale" {
  description = "ArgoCD UI via Tailscale Serve (configure with: tailscale serve --bg --https 8443 http://localhost:30080)"
  value       = "https://holdens-mac-mini.story-larch.ts.net:8443"
}

output "argocd_nodeport_http" {
  description = "ArgoCD HTTP NodePort (local access)"
  value       = "http://localhost:30080"
}

output "argocd_admin_password_command" {
  description = "Command to retrieve the initial ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "infisical_url_tailscale" {
  description = "Infisical UI via Tailscale Serve (configure with: tailscale serve --bg --https 8445 http://localhost:30445)"
  value       = "https://holdens-mac-mini.story-larch.ts.net:8445"
}

output "next_steps" {
  description = "Post-apply checklist"
  value       = <<-EOT
    1. Wait for ArgoCD to sync all Applications:
         kubectl get applications -n argocd -w

    2. Once Infisical is running, open the Infisical UI and create the following secrets
       in a project (e.g. "homelab / production"):
         - POSTGRES_PASSWORD       (gitea's PostgreSQL password)
         - POSTGRES_USER           (gitea)
         - GITEA_DB_PASSWORD       (same as POSTGRES_PASSWORD)
         - GITEA_SECRET_KEY        (random base64 string)

    3. Create a Machine Identity in Infisical UI:
         Settings → Machine Identities → Create → Universal Auth
       Then update terraform.tfvars with the new clientId / clientSecret and re-run:
         terraform apply

    4. ESO will reconcile ExternalSecrets and create K8s Secrets for PostgreSQL and Gitea.

    5. Configure Tailscale Serve (run once on the Mac mini):
         tailscale serve --bg http://localhost:30300          # Gitea
         tailscale serve --bg --https 8443 http://localhost:30080   # ArgoCD
         tailscale serve --bg --https 8444 https+insecure://localhost:30444  # Dashboard
         tailscale serve --bg --https 8445 http://localhost:30445   # Infisical
  EOT
}
