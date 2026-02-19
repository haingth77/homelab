---
name: gitops
description: ArgoCD GitOps workflows for the homelab. Manage applications, sync policies, kustomize manifests, and the App of Apps pattern.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔄",
        "requires": { "bins": ["kubectl"] },
      },
  }
---

# GitOps (ArgoCD)

Manage the homelab's GitOps pipeline. All cluster state is defined in `k8s/apps/` and synced by ArgoCD.

## Core rule

Never use `kubectl apply` for persistent changes. All changes go through git → ArgoCD sync. Manual kubectl changes are reverted by selfHeal within ~3 minutes.

## App of Apps pattern

The root Application (`argocd-apps`) watches `k8s/apps/argocd/`. Each child Application CR in that directory points to a service's manifest directory.

```
k8s/apps/argocd/kustomization.yaml  →  lists Application CRs
k8s/apps/argocd/applications/*.yaml  →  one per service
k8s/apps/<service>/                  →  kustomize manifests
```

## Application management

```bash
# List all applications and their sync status
kubectl get applications -n argocd

# Get detailed status for one application
kubectl get application <name> -n argocd -o yaml

# Force hard refresh (re-read from git)
kubectl patch application <name> -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check sync diff (what would change)
kubectl get application <name> -n argocd -o jsonpath='{.status.sync.status}'
```

## Sync waves

ESO uses sync waves to handle CRD dependencies:
- Wave 0: `external-secrets` (installs CRDs)
- Wave 1: `external-secrets-config` (applies ClusterSecretStore)
- Default: all other applications (no ordering)

## Adding a new application

1. Create `k8s/apps/<name>/` with manifests + `kustomization.yaml`
2. Create `k8s/apps/argocd/applications/<name>-app.yaml`
3. Add the file to `k8s/apps/argocd/kustomization.yaml` resources list
4. Push to `main`

## Troubleshooting

| Symptom | Fix |
|---|---|
| App stuck `OutOfSync` | Check ArgoCD can clone repo: `kubectl get secret repo-homelab -n argocd` |
| App stuck `Progressing` | Pod not ready: `kubectl describe pod -n <ns>` |
| CRD not found | Sync wave ordering issue: ensure wave 0 apps are healthy first |
| Changes not deploying | Wait ~3min or force refresh via annotation |
