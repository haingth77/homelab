---
name: devops-sre
description: Infrastructure provisioning, Kubernetes operations, Terraform management, CI/CD pipelines, monitoring, and incident response for the homelab cluster.
metadata:
  {
    "openclaw":
      {
        "emoji": "⚙️",
        "requires": { "anyBins": ["kubectl", "terraform"] },
      },
  }
---

# DevOps/SRE

Handle infrastructure, deployments, and reliability for the homelab Kubernetes cluster.

## Responsibilities

- Kubernetes cluster operations (OrbStack)
- Terraform bootstrap layer management
- ArgoCD application lifecycle
- Secret rotation via Infisical + ESO
- Tailscale networking and TLS
- Incident response and troubleshooting

## Terraform (bootstrap layer)

Terraform manages Layer 0 only: ArgoCD Helm release, bootstrap secrets, root Application CR. Located in `terraform/`.

```bash
cd terraform
terraform plan    # preview changes
terraform apply   # apply bootstrap changes
```

Terraform is for ArgoCD version upgrades, credential rotation, and initial cluster setup. Day-to-day operations use GitOps.

## Kubernetes debugging

```bash
# Pod status with resource usage
kubectl top pods -A

# Describe a failing pod
kubectl describe pod <name> -n <namespace>

# Get events sorted by time
kubectl get events -A --sort-by='.metadata.creationTimestamp'

# Check node resources
kubectl top nodes

# Debug a CrashLoopBackOff
kubectl logs <pod> -n <namespace> --previous
```

## Secret rotation

1. Update the secret value in Infisical UI (`homelab / prod`)
2. Force ESO re-sync: `kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite`
3. Restart the consuming deployment: `kubectl rollout restart deployment/<name> -n <ns>`

## Incident response checklist

1. Check pod status: `kubectl get pods -A | grep -v Running`
2. Check ArgoCD sync: `kubectl get applications -n argocd`
3. Check ESO health: `kubectl get clustersecretstore infisical`
4. Check node health: `kubectl get nodes`
5. Check recent events: `kubectl get events -A --sort-by='.metadata.creationTimestamp' | tail -20`
