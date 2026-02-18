# OpenClaw

Multi-channel AI gateway for agent orchestration in the homelab. OpenClaw provides a unified gateway that connects multiple AI model providers (Anthropic, OpenAI, etc.) and messaging channels into a single service.

## Architecture

```mermaid
flowchart TD
    subgraph openclawNs["openclaw namespace"]
        Deployment["OpenClaw Deployment\n1 replica"]
        Svc["Service\nNodePort :30789"]
        PVC["PVC: openclaw-data\n5Gi"]
        ES["ExternalSecret: openclaw-secret"]
        K8sSecret["K8s Secret: openclaw-secret"]
    end

    subgraph eso["external-secrets namespace"]
        CSS["ClusterSecretStore: infisical"]
    end

    subgraph infisical["Infisical"]
        Secrets["homelab / prod\nOPENCLAW_GATEWAY_TOKEN\nGEMINI_API_KEY"]
    end

    ES -- "secretStoreRef" --> CSS
    CSS -- "Universal Auth" --> Secrets
    Secrets --> K8sSecret
    K8sSecret -- "envFrom" --> Deployment
    Deployment --> PVC
    Svc --> Deployment
```

## Directory Contents

| File | Purpose |
|------|---------|
| `namespace.yaml` | Dedicated `openclaw` namespace |
| `pvc.yaml` | 5Gi persistent volume for OpenClaw state and workspace data |
| `external-secret.yaml` | Syncs gateway token and API keys from Infisical |
| `deployment.yaml` | Single-replica deployment with health probes |
| `service.yaml` | NodePort service exposing port 30789 |
| `kustomization.yaml` | Lists all resources |

## Image

The deployment uses a locally built Docker image (`openclaw:latest`) with `imagePullPolicy: Never`. OrbStack's Kubernetes cluster shares the host Docker daemon, so locally built images are immediately available.

Build the image:

```bash
./scripts/build-openclaw.sh
```

After updating the openclaw source, rebuild and restart:

```bash
./scripts/build-openclaw.sh
kubectl rollout restart deployment/openclaw -n openclaw
```

## Secrets

All secrets are stored in Infisical under `homelab / prod` and synced by ESO:

| Infisical Key | Description | Required |
|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | Auth token for gateway access (use `openssl rand -hex 32`) | Yes |
| `GEMINI_API_KEY` | Google Gemini API key from [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | At least one provider |

To add more model providers or channel tokens (e.g., `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `TELEGRAM_BOT_TOKEN`), add the key to Infisical, then add a new entry to `external-secret.yaml` and a corresponding `env` entry in `deployment.yaml`.

## Networking

| Layer | Value |
|---|---|
| Container port | 18789 |
| NodePort | 30789 |
| Tailscale HTTPS | 8446 |
| URL | `https://holdens-mac-mini.story-larch.ts.net:8446` |

One-time Tailscale Serve setup:

```bash
tailscale serve --bg --https 8446 http://localhost:30789
```

## Running CLI Commands Inside the Pod

The OpenClaw CLI is available inside the running pod. Use `kubectl exec` to run any `openclaw` subcommand:

```bash
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js <command>
```

The gateway listens on port 18789 (OpenClaw's default), so CLI commands auto-discover it without extra flags.

## Device Pairing (First Connection)

When you connect to the Control UI from a new browser or device, the gateway requires a **one-time pairing approval**. This is a security measure -- even with the correct gateway token, remote connections must be explicitly approved.

**What you'll see in the UI:** `disconnected (1008): pairing required`

**To approve the device:**

```bash
# 1. List pending pairing requests
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices list

# 2. Approve by request ID (from the "Request" column)
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices approve <requestId>
```

After approval, refresh the UI and click **Connect**. The device is remembered and won't require re-approval unless revoked.

**Notes:**

- Each browser profile generates a unique device ID -- switching browsers or clearing browser data requires re-pairing.
- Connections from `127.0.0.1` (e.g., `kubectl port-forward`) are auto-approved.
- All remote connections (Tailscale, LAN) require explicit approval.
- To revoke a device: `kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices revoke --device <id> --role <role>`

## Operational Commands

```bash
# Check pod status
kubectl get pods -n openclaw

# View logs
kubectl logs -n openclaw deploy/openclaw --tail=100

# Restart after image rebuild
kubectl rollout restart deployment/openclaw -n openclaw

# Check ExternalSecret status
kubectl get externalsecret -n openclaw

# Force secret re-sync
kubectl annotate externalsecret openclaw-secret -n openclaw \
  force-sync=$(date +%s) --overwrite

# Port-forward for local testing (bypasses Tailscale)
kubectl port-forward -n openclaw svc/openclaw 18789:18789

# --- OpenClaw CLI (inside the pod) ---

# List paired and pending devices
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices list

# Approve a pending device
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices approve <requestId>

# Gateway health check
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js health

# Open dashboard URL (prints the URL with embedded token)
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js dashboard --no-open

# List connected channels
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js channels status

# Run diagnostics
kubectl exec -n openclaw deploy/openclaw -- node dist/index.js doctor
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `disconnected (1008): pairing required` | New browser/device not approved | Run `kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices list` then `devices approve <requestId>` |
| `disconnected (1008): unauthorized: gateway token missing` | Token not entered in UI | Open Control UI settings and paste the `OPENCLAW_GATEWAY_TOKEN` value |
| `ErrImageNeverPull` | Image not built locally | Run `./scripts/build-openclaw.sh` |
| Pod `CrashLoopBackOff` | Missing secrets or bad config | Check `kubectl logs -n openclaw deploy/openclaw` |
| ExternalSecret `SecretSyncedError` | Secret not in Infisical | Add missing key to Infisical `homelab / prod` |
| `connection refused` on :30789 | Pod not running | `kubectl get pods -n openclaw` |
| Health check failing | Gateway still starting | Wait 30s; check logs for startup errors |
