---
name: gitops
description: ArgoCD GitOps workflows for the homelab. Manage applications, sync policies, kustomize manifests, and the App of Apps pattern. Includes the mandatory git workflow for all repo changes.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔄",
        "requires": { "bins": ["kubectl", "git", "gh"] },
      },
  }
---

# GitOps (ArgoCD)

Manage the homelab's GitOps pipeline. All cluster state is defined in `k8s/apps/` and synced by ArgoCD.

## Core rule

Never use `kubectl apply` for persistent changes. All changes go through git → ArgoCD sync. Manual kubectl changes are reverted by selfHeal within ~3 minutes.

## Mandatory Git Workflow

ALL changes to the homelab repository MUST follow this process. Never push directly to `main`.

### Workspace setup (once per session)

```bash
cd /data/workspaces/$(whoami 2>/dev/null || echo $HOSTNAME)
gh repo clone holdennguyen/homelab homelab 2>/dev/null || (cd homelab && git checkout main && git pull origin main)
cd homelab
```

### Step-by-step process

1. **Create a GitHub issue** — every change starts with an issue:
   ```bash
   gh issue create \
     --title "<type>: <description>" \
     --body "<why this change is needed>" \
     --repo holdennguyen/homelab
   ```
   Capture the issue number from the output.

2. **Create a branch** from latest main:
   ```bash
   git checkout main && git pull origin main
   git checkout -b <type>/<issue-number>-<short-description>
   ```

   Branch naming convention:
   | Prefix | Use for |
   |---|---|
   | `feat/` | New features, new services, new resources |
   | `fix/` | Bug fixes, misconfigurations |
   | `chore/` | Maintenance, dependency updates, cleanup |
   | `docs/` | Documentation-only changes |
   | `refactor/` | Restructuring without behavior change |

3. **Make changes** to the appropriate files:
   - Kubernetes manifests: `k8s/apps/<service>/`
   - ArgoCD applications: `k8s/apps/argocd/applications/`
   - Terraform (Layer 0): `terraform/`
   - Documentation: `k8s/apps/<service>/README.md` (single source of truth)

4. **Commit** referencing the issue:
   ```bash
   git add <files>
   git commit -m "<type>: <description> (#<issue-number>)"
   ```

5. **Push and create a PR**:
   ```bash
   git push -u origin HEAD
   gh pr create \
     --title "<type>: <description>" \
     --body "$(cat <<'EOF'
   Closes #<issue-number>

   ## Summary
   - <bullet points: what changed and why>

   ## Test plan
   - [ ] ArgoCD syncs successfully
   - [ ] Service health verified
   - [ ] Documentation updated
   EOF
   )"
   ```

6. **Report** the PR URL to the user or orchestrator agent.

### After merge

- **Layer 1 (k8s manifests):** ArgoCD auto-syncs within ~3 minutes. Verify: `kubectl get applications -n argocd`
- **Layer 0 (Terraform):** Requires manual `terraform apply` on the host after merge.
- **Docker image changes:** Requires `./scripts/build-openclaw.sh` + `kubectl rollout restart` on the host.

### What NOT to do

- Never push directly to `main`
- Never commit secrets, API keys, or credentials
- Never bundle unrelated changes in one PR
- Never use `kubectl apply` for persistent resources (ArgoCD will revert them)

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

Follow the mandatory git workflow above, then:

1. Create `k8s/apps/<name>/` with manifests + `kustomization.yaml`
2. Create `k8s/apps/argocd/applications/<name>-app.yaml`
3. Add the file to `k8s/apps/argocd/kustomization.yaml` resources list
4. Update `k8s/apps/<name>/README.md` and `docs/<name>.md`
5. Commit, push, and create PR

## Troubleshooting

| Symptom | Fix |
|---|---|
| App stuck `OutOfSync` | Check ArgoCD can clone repo: `kubectl get secret repo-homelab -n argocd` |
| App stuck `Progressing` | Pod not ready: `kubectl describe pod -n <ns>` |
| CRD not found | Sync wave ordering issue: ensure wave 0 apps are healthy first |
| Changes not deploying | Wait ~3min or force refresh via annotation |
