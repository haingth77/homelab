---
name: secret-management
description: Manage secrets through the Infisical → External Secrets Operator → Kubernetes pipeline. Add, rotate, and troubleshoot secrets without storing them in git.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["kubectl"] },
      },
  }
---

# Secret Management

All secrets flow through: Infisical (source of truth) → ESO (sync) → K8s Secret (consumed by pods). Secrets never live in git.

## Adding a secret for a service

1. Add the key/value to Infisical UI under `homelab / prod`
2. Add an entry to the service's `external-secret.yaml`:
   ```yaml
   - secretKey: MY_KEY
     remoteRef:
       key: MY_KEY
   ```
3. Add the env var to the service's `deployment.yaml`:
   ```yaml
   - name: MY_KEY
     valueFrom:
       secretKeyRef:
         name: <service>-secret
         key: MY_KEY
   ```
4. Push to `main` — ArgoCD syncs, ESO creates the K8s Secret

## Rotating a secret

1. Update the value in Infisical
2. Force ESO re-sync:
   ```bash
   kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite
   ```
3. Restart the consuming deployment:
   ```bash
   kubectl rollout restart deployment/<name> -n <ns>
   ```

## Checking secret health

```bash
# ClusterSecretStore connectivity
kubectl get clustersecretstore infisical
kubectl describe clustersecretstore infisical

# All ExternalSecrets across the cluster
kubectl get externalsecret -A

# Decode a secret value
kubectl get secret <name> -n <ns> -o jsonpath='{.data.<KEY>}' | base64 -d
```

## Current secrets

| ExternalSecret | Namespace | Keys |
|---|---|---|
| `postgresql-secret` | `gitea-system` | POSTGRES_PASSWORD, POSTGRES_USER, POSTGRES_DB, GITEA_DB_PASSWORD |
| `gitea-secret` | `gitea-system` | GITEA_SECRET_KEY |
| `gitea-admin-secret` | `gitea-system` | GITEA_ADMIN_USERNAME, GITEA_ADMIN_PASSWORD, GITEA_ADMIN_EMAIL |
| `openclaw-secret` | `openclaw` | OPENCLAW_GATEWAY_TOKEN, OPENROUTER_API_KEY, GEMINI_API_KEY |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `InvalidProviderConfig` on ClusterSecretStore | Check Infisical machine identity credentials |
| 401 Unauthorized | Update clientId/clientSecret in `terraform.tfvars`, run `terraform apply` |
| 403 Forbidden | Add machine identity to the `homelab` project in Infisical |
| ExternalSecret stuck `SecretSyncedError` | Force re-sync with annotation |
