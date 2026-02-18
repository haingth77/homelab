# Homelab

A GitOps-managed Kubernetes homelab running on OrbStack (Mac mini M4). Deploys self-hosted infrastructure services -- currently Gitea and PostgreSQL -- orchestrated by Argo CD, with AI agent skill definitions for multi-agent development workflows.

## Architecture

```mermaid
flowchart TD
    subgraph dev["Developer Workstation (Mac mini M4)"]
        Git["Git CLI"]
    end

    GitHub["GitHub\nholdennguyen/homelab"]

    subgraph tailnet["Tailscale Network"]
        TServe["tailscale serve\nHTTPS with auto TLS"]
    end

    subgraph orb["OrbStack Kubernetes Cluster"]
        subgraph argocdNs["argocd namespace"]
            ArgoCD["Argo CD\nNodePort :30080/:30443"]
        end

        subgraph giteaNs["gitea-system namespace"]
            direction LR
            GiteaPod["Gitea Pod\ngitea/gitea:1.22"]
            PostgresPod["PostgreSQL Pod\npostgres:15"]
            GiteaSvc["Gitea Service\nNodePort :30300/:30022"]
            PostgresSvc["PostgreSQL Service\n:5432"]
        end
    end

    Git -- "git push" --> GitHub
    GitHub -- "poll & sync" --> ArgoCD
    ArgoCD -- "manages" --> giteaNs
    TServe -- ":443 -> localhost:30300" --> GiteaSvc
    TServe -- ":8443 -> localhost:30443" --> ArgoCD
    GiteaSvc --> GiteaPod
    GiteaPod -- "PASSWD from Secret" --> PostgresSvc
    PostgresSvc --> PostgresPod
```

## Repository Structure

```
homelab/
├── README.md
├── agents/                        # AI agent skill definitions
│   ├── root_rules.md              # Shared rules all agents follow
│   ├── devops_sre_agent/          # Infrastructure & reliability
│   ├── software_engineer_agent/   # Code development
│   ├── qa_tester_agent/           # Testing & quality
│   ├── product_manager_agent/     # Product planning
│   ├── data_scientist_agent/      # Data analysis
│   └── security_analyst_agent/    # Security operations
├── k8s/                           # Kubernetes manifests (GitOps root)
│   └── apps/
│       ├── argocd/                # Argo CD + Application definitions
│       ├── gitea/                 # Gitea git server manifests
│       └── postgresql/            # PostgreSQL database manifests
├── openclaw/                      # Core AI agent framework (submodule)
└── skills/                        # Shared agent skill modules
```

## GitOps Flow

Every change follows the same path: commit to `main`, push to GitHub, Argo CD detects the change and syncs the cluster.

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub (main)
    participant Argo as Argo CD
    participant K8s as Kubernetes

    Dev->>GH: git push
    loop Every ~3 minutes
        Argo->>GH: Poll for changes
    end
    GH-->>Argo: New commit detected
    Argo->>Argo: Render manifests (Kustomize)
    Argo->>K8s: Apply diff
    K8s-->>Argo: Resource status
    Note over Argo: selfHeal=true reverts<br/>any manual kubectl changes
```

## Deployed Services

| Service | Image | Namespace | Access | Status |
|---------|-------|-----------|--------|--------|
| Argo CD | upstream `stable` | `argocd` | `https://holdens-mac-mini.story-larch.ts.net:8443` | Healthy |
| PostgreSQL | `postgres:15` | `gitea-system` | ClusterIP `postgresql:5432` (internal only) | Healthy |
| Gitea | `gitea/gitea:1.22` | `gitea-system` | `https://holdens-mac-mini.story-larch.ts.net` | Running |

## Quick Start

### Prerequisites

- OrbStack with Kubernetes enabled
- `kubectl` configured to the OrbStack cluster
- Git push access to `github.com/holdennguyen/homelab`
- Tailscale installed with Serve enabled on the tailnet

### Bootstrap Argo CD

```bash
kubectl apply -k k8s/apps/argocd --server-side --force-conflicts

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Argo CD self-manages after the initial `kubectl apply`. It also deploys the PostgreSQL and Gitea Application definitions bundled in `k8s/apps/argocd/kustomization.yaml`.

### Expose Services via Tailscale

Services are exposed through `tailscale serve`, which provides auto-provisioned TLS certificates and makes them accessible from any device on the tailnet.

```bash
# Gitea on default HTTPS port
tailscale serve --bg http://localhost:30300

# ArgoCD on port 8443
tailscale serve --bg --https 8443 https+insecure://localhost:30443

# Verify
tailscale serve status
```

Access URLs (from any Tailscale device):

- Gitea: `https://holdens-mac-mini.story-larch.ts.net`
- ArgoCD: `https://holdens-mac-mini.story-larch.ts.net:8443`

### Verify Deployment

```bash
# Check Argo CD applications
kubectl get applications -n argocd

# Check running pods
kubectl get pods -n gitea-system

# Test Gitea API
kubectl exec -n gitea-system deploy/gitea -c gitea -- \
  wget -qO- http://localhost:3000/api/v1/settings/api

# Test PostgreSQL
kubectl exec -n gitea-system deploy/postgresql -- \
  psql -U gitea -d gitea -c '\dt'
```

## Component Documentation

Each service has detailed documentation covering its configuration, integration points, and operational notes:

- [Argo CD](k8s/apps/argocd/README.md) -- GitOps controller, Application definitions, sync policies
- [PostgreSQL](k8s/apps/postgresql/README.md) -- Database configuration, pg_hba.conf, PGDATA layout, Secret management
- [Gitea](k8s/apps/gitea/README.md) -- Config seeding via init container, env var overrides, Tailscale networking

## Future Plans

1. **Observability** -- Prometheus, Grafana, Loki for monitoring and logging
2. **Secret Management** -- Sealed Secrets or External Secrets Operator to replace plaintext base64 Secrets
3. **CI/CD Pipelines** -- Gitea Actions or Tekton for build and test automation
4. **Openclaw Deployment** -- Containerize and deploy the AI agent framework to the cluster
5. **Agent Expansion** -- Develop and integrate more AI agents for homelab automation
6. **Security Hardening** -- Network policies, RBAC, TLS everywhere, image scanning
