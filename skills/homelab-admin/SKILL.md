---
name: homelab-admin
description: Manage the homelab Kubernetes cluster, GitOps workflows, and infrastructure services. Use for kubectl operations, ArgoCD sync, Tailscale networking, and general homelab administration.
metadata:
  {
    "openclaw":
      {
        "emoji": "🏠",
        "requires": { "anyBins": ["kubectl", "terraform"] },
      },
  }
---

# Homelab Admin

Orchestrate and manage the homelab Kubernetes cluster running on OrbStack (Mac mini M4). This skill covers day-to-day operations across all deployed services.

## Cluster overview

- **Runtime:** OrbStack Kubernetes (single-node, Mac mini M4)
- **GitOps:** ArgoCD polls `github.com/holdennguyen/homelab` and syncs `k8s/apps/`
- **Secrets:** Infisical → External Secrets Operator → K8s Secrets
- **Networking:** NodePort + Tailscale Serve (auto TLS)
- **Manifests:** Kustomize (no Helm for app workloads)

## Services

| Service | Namespace | NodePort | Tailscale |
|---|---|---|---|
| ArgoCD | `argocd` | 30080 | :8443 |
| Infisical | `infisical` | 30445 | :8445 |
| Gitea | `gitea-system` | 30300 | :443 |
| PostgreSQL | `gitea-system` | internal | internal |
| K8s Dashboard | `kubernetes-dashboard` | 30444 | :8444 |
| OpenClaw | `openclaw` | 30789 | :8446 |

## Common operations

```bash
# Check all ArgoCD applications
kubectl get applications -n argocd

# Check pods across all namespaces
kubectl get pods -A

# Force ArgoCD sync on an application
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check ExternalSecrets cluster-wide
kubectl get externalsecret -A

# View ArgoCD logs
kubectl logs -n argocd deploy/argocd-server --tail=50

# Restart a deployment
kubectl rollout restart deployment/<name> -n <namespace>
```

## GitOps workflow

All changes follow: edit manifests in `k8s/apps/` → commit → push to `main` → ArgoCD syncs within ~3 minutes. Never use `kubectl apply` for persistent changes.

## Adding a new service

1. Create `k8s/apps/<service>/` with manifests and `kustomization.yaml`
2. Create `k8s/apps/argocd/applications/<service>-app.yaml`
3. Add to `k8s/apps/argocd/kustomization.yaml`
4. Push to `main`

## Adding secrets for a service

1. Add secret to Infisical under `homelab / prod`
2. Create `ExternalSecret` resource in the service's k8s directory
3. Reference the created K8s Secret in the Deployment env vars
4. Push to `main`

## Tailscale Serve management

```bash
# Check current serve status
tailscale serve status

# Add a new service
tailscale serve --bg --https <port> http://localhost:<nodeport>

# Remove a service
tailscale serve --https=<port> off
```
