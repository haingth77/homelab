---
name: incident-response
description: Incident response, rollback procedures, ArgoCD recovery, and post-incident documentation for the homelab cluster. Use when a deployment causes service degradation or when you need to roll back a change.
---

# Incident Response & Rollback

Procedures for detecting, triaging, rolling back, and documenting incidents in the GitOps-managed homelab cluster.

## Severity Classification

| Severity | Criteria | Response Time |
|---|---|---|
| **SEV-1** | Multiple services down, data loss risk, security breach | Immediate |
| **SEV-2** | Single service down or degraded, no data loss | Within 15 minutes |
| **SEV-3** | Non-critical service degraded, workaround exists | Within 1 hour |
| **SEV-4** | Cosmetic issue, no user impact | Next available cycle |

## Phase 1: Detection & Triage

```bash
kubectl get applications -n argocd
kubectl get pods -A | grep -v Running | grep -v Completed
kubectl get events -A --sort-by='.lastTimestamp' --field-selector type!=Normal | tail -30
kubectl describe pod <crashing-pod> -n <namespace>
kubectl logs -n <namespace> deploy/<name> --tail=100
```

**Triage checklist:**
- Which services are affected? (blast radius)
- What was the last change merged to `main`? (`git log -5 --oneline`)
- Are pods crashing (`CrashLoopBackOff`) or stuck (`Pending`/`Progressing`)?
- Is the issue caused by the new change or a pre-existing condition?
- Severity classification (SEV-1 through SEV-4)

## Phase 2: Rollback

Roll back immediately if:
- A service is in `CrashLoopBackOff` after a merge
- ArgoCD shows `Degraded` for any application
- Health checks or endpoints are unreachable

### Option A: Git revert (preferred)

```bash
git log --oneline -10
git revert <bad-commit-sha> -m 1 --no-edit
git push origin main
```

### Option B: File-level restore (multi-commit)

```bash
git checkout <known-good-sha> -- path/to/file1.yaml path/to/file2.yaml
git commit -m "revert: restore files to pre-<description> state"
git push origin main
```

### Option C: Emergency kubectl override (SEV-1 only)

```bash
kubectl rollout undo deployment/<name> -n <namespace>
```

Always follow up with a proper git revert — kubectl changes are temporary (ArgoCD overwrites within ~3 minutes).

## Phase 3: ArgoCD Recovery

```bash
# Force hard refresh on all applications
for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do
  kubectl patch application "$app" -n argocd \
    --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
done

# Cancel stuck sync
kubectl patch application <app-name> -n argocd \
  --type json -p '[{"op":"remove","path":"/operation"}]'

# Force-delete crashing pod
kubectl delete pod <crashing-pod> -n <namespace> --force --grace-period=0
```

## Phase 4: Post-Rollback Verification

```bash
kubectl get applications -n argocd
kubectl get pods -A | grep -v Running | grep -v Completed
kubectl get externalsecrets -A
curl -sf http://localhost:30300/api/v1/version   # Gitea
curl -sf http://localhost:30789/health            # OpenClaw
kubectl get events -A --sort-by='.lastTimestamp' --field-selector type!=Normal | tail -10
```

All checks must pass before the rollback is considered complete.

## Post-Incident Documentation

After every incident (SEV-1 through SEV-3), document on the related GitHub issue or PR:

1. **Timeline** — chronological events (merge, detection, triage, rollback, recovery)
2. **Root cause** — the specific technical cause
3. **Blast radius** — which services, for how long
4. **Resolution** — revert commit SHA, manual steps
5. **Lessons learned** — what could have prevented this
6. **Action items** — concrete follow-up tasks

## Post-Incident Cleanup

1. **Reopen the original issue** — the revert means the feature was NOT delivered
2. **Label the reverted PR** with `status:reverted`
3. **Assign milestones** — original issue to future milestone, reverted PR stays in current
4. **Create per-service sub-issues** for re-implementation
5. **Triage sibling PRs** — close unreviewed PRs from the same batch

## Troubleshooting

| Symptom | Fix |
|---|---|
| `git revert` has conflicts | Use file-level restore (Option B) |
| ArgoCD stuck `Progressing` | Cancel operation + force-delete pod |
| Revert pushed but ArgoCD not syncing | Force hard refresh on all applications |
| `kubectl rollout undo` reverted by ArgoCD | Push git revert ASAP; kubectl undo is temporary |
| Helm values silently ignored | Verify keys with `helm show values` before PRs |
