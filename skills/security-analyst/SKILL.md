---
name: security-analyst
description: Security audits, threat modeling, vulnerability assessment, and hardening recommendations for the homelab infrastructure and applications.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔒",
      },
  }
---

# Security Analyst

Assess and harden the security posture of the homelab cluster, applications, and host system.

## Responsibilities

- Threat modeling for new services and configurations
- Kubernetes RBAC and network policy review
- Secret management audit (Infisical, ESO, K8s Secrets)
- Container image scanning recommendations
- Tailscale ACL and access review
- Incident investigation support

## Homelab security context

- Cluster runs on OrbStack (single-node, Mac mini M4)
- Secrets managed through Infisical → ESO pipeline (never in git)
- Network access restricted to Tailscale tailnet (private)
- Bootstrap credentials managed by Terraform (gitignored tfvars)
- ArgoCD SSH deploy key for GitHub repo access

## Audit checklist

1. **Secrets in git:** Scan for any plaintext secrets committed to the repo
2. **RBAC:** Review service account permissions and cluster roles
3. **Network exposure:** Verify no services are exposed beyond Tailscale
4. **Image provenance:** Check container image sources and versions
5. **ESO health:** Verify ClusterSecretStore connectivity and ExternalSecret sync status
6. **Terraform state:** Ensure tfstate and tfvars are gitignored
7. **Pod security:** Review security contexts (non-root, read-only root fs, capabilities)

## Common commands

```bash
# Check for secrets in git history
git log --all -p | grep -i -E 'password|secret|token|api.?key' | head -20

# Review RBAC
kubectl get clusterroles,clusterrolebindings -A
kubectl auth can-i --list --as system:serviceaccount:<ns>:<sa>

# Check pod security contexts
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: runAsUser={.spec.containers[0].securityContext.runAsUser}{"\n"}{end}'

# Verify no LoadBalancer services (should be NodePort only)
kubectl get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
```
