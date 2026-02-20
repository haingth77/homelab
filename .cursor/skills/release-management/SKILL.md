---
name: release-management
description: Release checklist, version tagging, doc freshness sweep, and root README review. Use when cutting a new release or preparing a milestone for release.
disable-model-invocation: true
---

# Release Management

Before tagging a new release (e.g. `v1.1.0`), complete every item in this checklist.

## Pre-Release Checklist

1. **All milestone PRs merged** — no open PRs targeting this release
2. **ArgoCD health** — all applications `Synced` + `Healthy`:
   ```bash
   kubectl get applications -n argocd
   ```
3. **Doc freshness** — run and resolve any stale entries:
   ```bash
   python scripts/doc-freshness.py --stale
   ```
4. **Root README review** — the root `README.md` is the public face of the repo. It is tracked in `.doc-manifest.yml` with narrow sources (kustomization.yaml, mkdocs.yml), but those triggers only catch structural additions. Manually review and update:
   - Architecture diagram — does it reflect all current namespaces and services?
   - Repository structure — any new top-level directories or service directories?
   - Deployed services table — any new services, changed ports, or removed services?
   - Documentation index — does the table list every doc file?
   - Quick Start / secrets table — any new secrets or changed bootstrap steps?
   - Future Plans — move completed items out, add new plans
5. **Run doc freshness again** after updates to confirm all clear:
   ```bash
   python scripts/doc-freshness.py --stale
   ```
6. **Tag and release:**
   ```bash
   git tag -a vX.Y.Z -m "release description" && git push origin vX.Y.Z
   ```

## Semantic Versioning

The repo follows `vMAJOR.MINOR.PATCH`:

| Condition | Bump |
|---|---|
| Any PR has `semver:breaking` label | **MAJOR** |
| At least one `type:feat` (no breaking) | **MINOR** |
| Only `type:fix` / `type:chore` / `type:docs` / `type:refactor` / `type:security` | **PATCH** |

## Milestone Lifecycle

```bash
# Check for open milestones
gh api repos/holdennguyen/homelab/milestones --jq '.[] | select(.state=="open") | .title' | head -1

# Verify milestone completeness
gh api repos/holdennguyen/homelab/milestones --jq '.[] | select(.title=="<version>") | "open: \(.open_issues), closed: \(.closed_issues)"'

# Close milestone after release
gh api repos/holdennguyen/homelab/milestones/<number> --method PATCH -f state="closed"

# Create next milestone
gh api repos/holdennguyen/homelab/milestones --method POST -f title="v<next>" -f description="<goal>"
```
