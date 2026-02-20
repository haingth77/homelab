# Trivy Operator

Trivy Operator is a Kubernetes operator that continuously scans container images for vulnerabilities and generates `VulnerabilityReport` resources for each running pod.

## Overview

- **Helm Chart**: `aquasecurity/trivy-operator`
- **Namespace**: `monitoring`
- **Reports**: View vulnerabilities with `kubectl get vulnerabilityreports -n <pod-namespace>`
- **Integration**: Works natively with Prometheus and Grafana (dashboards can be added)

## Architecture

Trivy Operator watches Kubernetes pods, extracts their container images, and scans them using the Trivy vulnerability database. It creates a `VulnerabilityReport` custom resource for each pod, summarizing found CVEs along with fix availability.

```mermaid
flowchart TD
    subgraph cluster["Kubernetes Cluster"]
        OP[Trivy Operator<br/>Deployment]
        Pod1[Pod with Image]
        Pod2[Pod with Image]
        VR[VulnerabilityReport<br/>Custom Resource]
    end
    OP -->|watches| Pod1
    OP -->|watches| Pod2
    OP -->|creates| VR
```

## Configuration

The operator is deployed with default settings, which:

- Scan images of running pods
- Scan on pod creation and at regular intervals
- Do not block pod scheduling (report-only)
- Store reports as Kubernetes custom resources

### Helm Values

Overrides can be made in the Application CR's `spec.source.helm.valuesObject`.

Key options:
- `operator.resources`: CPU/memory requests/limits
- `trivy.ignoreUnfixed`: whether to ignore vulnerabilities without a fix
- `trivy.severity`: filter by severity (e.g., `HIGH`, `CRITICAL`)

Refer to the [Trivy Operator documentation](https://github.com/aquasecurity/trivy-operator) for advanced configuration.

## Secrets

No secrets are required; the operator uses read-only access to the Kubernetes API and the container runtime (via hostPID and container runtime socket).

## Networking

- The operator needs egress to container registries to download image layers for scanning.
- It may also need egress to the internet for vulnerability database updates (via `aquasecurity/trivy-db`).
- Ensure that egress to `ghcr.io`, `docker.io`, and other registries is allowed on HTTPS (443). This should be covered by the default internet egress from the `monitoring` namespace (if network policies are in place).

## Operational Commands

```bash
# List all vulnerability reports
kubectl get vulnerabilityreports --all-namespaces

# View report for a specific pod
kubectl get vulnerabilityreport <pod-name> -n <namespace> -o yaml

# Delete old reports (they are automatically garbage-collected)
kubectl delete vulnerabilityreport --all -n <namespace>
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| No VulnerabilityReport CRs appear | Operator not running or RBAC issues | Check pod logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=trivy-operator` |
| Reports show `FAILED` | Image scan failed (private registry, large image, timeout) | Verify image pull secret exists; consider increasing resources/timeouts |
| High CPU/Memory usage | Scanning many large images | Adjust operator resources; consider increasing limits |
