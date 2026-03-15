# Setup Guide — Mac mini M4 (Step-by-Step)

This guide is for setting up the homelab **on the Mac mini M4 only**. All commands below are intended to be run on that machine. Use it as a checklist; each section states **where** to run and **what** to run.

**This variant skips Grafana and monitoring** — you can add them later. Tailscale is assumed with DNS: **folk-adelie.ts.net**; Mac mini hostname **hardy-mac-mini** (services at `https://hardy-mac-mini.folk-adelie.ts.net`). Other devices (e.g. **hardy-iphone**) on the same tailnet can use the same URLs.

---

## 0. Prerequisites (Mac mini M4)

Install and verify these on the Mac mini:

| Tool | Version | Install | Verify |
|------|---------|--------|--------|
| **OrbStack** | latest | [orbstack.dev](https://orbstack.dev) | Open OrbStack → enable **Kubernetes** in settings |
| **kubectl** | any | `brew install kubectl` | `kubectl version --client` |
| **terraform** | >= 1.5 | `brew install terraform` | `terraform version` |
| **helm** | any | `brew install helm` | `helm version` |
| **Docker** | (from OrbStack) | — | `docker info` |
| **Tailscale** | latest | [tailscale.com/download](https://tailscale.com/download) | `tailscale status` |
| **openssl** | (built-in) | — | `openssl version` |
| **git** | any | `brew install git` | `git --version` |

Confirm Kubernetes is running and context is correct:

```bash
# On Mac mini M4
kubectl config current-context   # should print: orbstack
kubectl cluster-info             # should show API server URL
kubectl get nodes                # one node, Ready
```

---

## 1. Clone Repository and Submodule (Mac mini M4)

**Where:** Mac mini M4, any directory you want the repo in (e.g. home or `~/Projects`).

```bash
# Replace with your chosen path; homelab docs often assume ~/homelab
git clone https://github.com/haingth77/homelab.git
cd homelab
git submodule update --init
```

The `openclaw` directory must be populated; without it the OpenClaw image build will fail.

**Note:** The OpenClaw deployment uses **hostPath** with a fixed path. If you do **not** use `~/homelab` (i.e. your path is e.g. `/Users/<your-username>/Projects/homelab`), you will need to fix the paths in [Step 8](#8-openclaw-hostpath-mac-mini-m4).

---

## 2. Generate Bootstrap Secrets (Mac mini M4)

**Where:** Mac mini M4, terminal. Run these and **save the outputs** for the next step (e.g. in a temporary note; do not commit them).

```bash
# Infisical ENCRYPTION_KEY (32-char hex)
openssl rand -hex 16

# Infisical AUTH_SECRET (base64)
openssl rand -base64 32

# Infisical PostgreSQL password
openssl rand -hex 12

# Infisical Redis password
openssl rand -hex 12
```

---

## 3. Create terraform.tfvars (Mac mini M4)

**Where:** Mac mini M4, inside the cloned repo.

```bash
cd homelab
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and set every value:

| Variable | Example / how to get it |
|----------|-------------------------|
| `kube_context` | `"orbstack"` (default) |
| `argocd_version` | `"7.8.0"` (or leave as in example) |
| `tailscale_host` | `"hardy-mac-mini.folk-adelie.ts.net"` (your Tailscale hostname; used for Argo CD URL) |
| `authentik_base_url` | `"https://hardy-mac-mini.folk-adelie.ts.net:8444"` (Authentik URL; use :8444 to avoid TLS issues on 443) |
| `infisical_encryption_key` | Output of `openssl rand -hex 16` from Step 2 |
| `infisical_auth_secret` | Output of `openssl rand -base64 32` from Step 2 |
| `infisical_postgres_password` | Output of first `openssl rand -hex 12` from Step 2 |
| `infisical_redis_password` | Output of second `openssl rand -hex 12` from Step 2 |
| `infisical_machine_identity_client_id` | Use `"placeholder-update-after-infisical-starts"` for first apply |
| `infisical_machine_identity_client_secret` | Use `"placeholder-update-after-infisical-starts"` for first apply |
| `argocd_oidc_client_secret` | Use `"placeholder"` until Authentik is running; set after [Step 6](#6-infisical-ui-and-machine-identity-mac-mini-m4) and Authentik OIDC provider creation |

Do **not** commit `terraform.tfvars`; it is gitignored.

---

## 4. Bootstrap with Terraform (Mac mini M4)

**Where:** Mac mini M4, from repo root.

```bash
cd homelab/terraform
terraform init
terraform plan
terraform apply
```

Confirm with `yes` when prompted. This will:

- Create namespaces: `argocd`, `infisical`, `external-secrets`
- Install Argo CD via Helm (NodePort :30080)
- Create bootstrap K8s Secrets (Infisical encryption, machine identity placeholder, etc.)
- Register the root Argo CD Application (App of Apps)

After apply, Argo CD will start syncing. In another terminal you can watch:

```bash
kubectl get pods -n argocd -w
kubectl get applications -n argocd -w
```

---

## 5. Wait for Infisical to Be Ready (Mac mini M4)

**Where:** Mac mini M4.

Infisical is deployed by Argo CD. Wait until it is up so you can log in and create the project.

```bash
kubectl get pods -n infisical -w
# Wait until the main Infisical pod is Running and Ready (e.g. 1/1).
# Ctrl+C to stop -w when done.
```

Get the NodePort (should be 30445):

```bash
kubectl get svc -n infisical -l app.kubernetes.io/component=infisical
```

You can open Infisical at `http://localhost:30445` or, after Step 7, at `https://hardy-mac-mini.folk-adelie.ts.net:8445`.

---

## 6. Infisical UI and Machine Identity (Mac mini M4)

**Where:** Browser (on any device that can reach the Mac mini, or on the Mac mini via localhost after Step 7).

1. **First login:** Open Infisical (e.g. `http://localhost:30445`). Create the **first admin account** (signup).
2. **Create project:** New Project → name **homelab**, slug **must** be **homelab**.
3. **Add application secrets** in project **homelab**, environment **prod**, path `/` (no Grafana/monitoring in this setup):

   | Key | How to get / generate |
   |-----|------------------------|
   | `AUTHENTIK_SECRET_KEY` | `openssl rand -hex 32` |
   | `AUTHENTIK_BOOTSTRAP_PASSWORD` | Choose a strong admin password |
   | `AUTHENTIK_BOOTSTRAP_TOKEN` | `openssl rand -hex 32` |
   | `AUTHENTIK_POSTGRES_PASSWORD` | `openssl rand -hex 12` |
   | `OPENCLAW_GATEWAY_TOKEN` | `openssl rand -hex 32` |
   | `OPENROUTER_API_KEY` | [openrouter.ai/keys](https://openrouter.ai/keys) |
   | `GEMINI_API_KEY` | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
   | `GITHUB_TOKEN` | GitHub PAT (e.g. fine-grained) with repo scope for this homelab repo |
   | `DISCORD_BOT_TOKEN` | Discord Developer Portal → Your App → Bot → Reset Token (see [OpenClaw README](../../k8s/apps/openclaw/README.md) for full Discord setup) |
   | `DISCORD_WEBHOOK_DEUTSCH` | Optional — Discord channel webhook URL |
   | `DISCORD_WEBHOOK_ENGLISH` | Optional — Discord channel webhook URL |
   | `DISCORD_WEBHOOK_DAILY` | Optional — Discord channel webhook URL |
   | `DISCORD_WEBHOOK_ALERTS` | Optional — Discord channel webhook URL |
   | `CURSOR_API_KEY` | Optional — Cursor API key for cursor-agent |

4. **Machine Identity for ESO:**
   - Infisical: **Settings → Machine Identities → Create**
   - Name: `homelab-eso`, Auth: **Universal Auth** → Create
   - Copy **clientId** and **clientSecret**
   - In project **homelab**: **Access Control → Machine Identities → Add** → select `homelab-eso` with **Member** role

5. **Update Terraform and re-apply** so ESO can authenticate:

   On Mac mini:

   ```bash
   cd homelab
   # Edit terraform/terraform.tfvars and set:
   #   infisical_machine_identity_client_id     = "<clientId>"
   #   infisical_machine_identity_client_secret = "<clientSecret>"
   cd terraform
   terraform apply
   ```

6. **Verify ESO:**

   ```bash
   kubectl get clustersecretstore infisical
   # STATUS should show Valid / Ready: True
   ```

When Authentik is running, create an OAuth2 provider with `client_id = argocd`, then set `argocd_oidc_client_secret` in `terraform.tfvars` and run `terraform apply` again (see [Terraform README](../../terraform/README.md)).

---

## 7. Tailscale Serve (Mac mini M4)

**Where:** Mac mini M4. Run once; persists across reboots until you change or disable Serve.

Tailscale DNS: **folk-adelie.ts.net**. Mac mini: **hardy-mac-mini**. Base URL: **https://hardy-mac-mini.folk-adelie.ts.net**. Access from **hardy-iphone** or any other device on the same tailnet using the same URLs.

Authentik is exposed on **port 8444** (not default 443) to avoid Tailscale Serve TLS issues on port 443. Ensure `authentik_base_url` in `terraform.tfvars` matches (e.g. `https://hardy-mac-mini.folk-adelie.ts.net:8444`).

Ensure Tailscale is connected (`tailscale status`). Then (no Grafana/monitoring in this setup):

```bash
tailscale serve --bg --https 8444 http://localhost:30500            # Authentik (SSO) — use 8444, not 443
tailscale serve --bg --https 8443 http://localhost:30080          # Argo CD
tailscale serve --bg --https 8445 http://localhost:30445          # Infisical
tailscale serve --bg --https 8446 http://localhost:30100          # LaunchFast
tailscale serve --bg --https 8447 http://localhost:30789          # OpenClaw
tailscale serve --bg --https 8448 http://localhost:30448           # Trivy Dashboard
tailscale serve status
```

| Service | URL |
|---------|-----|
| Authentik (SSO) | `https://hardy-mac-mini.folk-adelie.ts.net:8444` |
| Argo CD | `https://hardy-mac-mini.folk-adelie.ts.net:8443` |
| Infisical | `https://hardy-mac-mini.folk-adelie.ts.net:8445` |
| LaunchFast | `https://hardy-mac-mini.folk-adelie.ts.net:8446` |
| OpenClaw | `https://hardy-mac-mini.folk-adelie.ts.net:8447` |
| Trivy Dashboard | `https://hardy-mac-mini.folk-adelie.ts.net:8448` |

**Authentik on port 8444:** So that the Argo CD pod (via hostAlias) can reach the OIDC issuer at `authentik_base_url`, the Authentik server Service must expose port 8444. If the chart only exposes 80/443, add the port once (replace `<svc-name>` with the server service name, e.g. `authentik-server`):

```bash
kubectl get svc -n authentik -l app.kubernetes.io/component=server -o name
kubectl patch svc -n authentik <svc-name> --type='json' -p='[{"op":"add","path":"/spec/ports/-","value":{"name":"https-alt","port":8444,"targetPort":9443,"protocol":"TCP"}}]'
```

In Authentik Admin, set the Argo CD provider **Redirect URI** to `https://hardy-mac-mini.folk-adelie.ts.net:8443/auth/callback` (unchanged).

---

## 7b. Fix Argo CD login via Authentik (EOF when querying provider)

**Where:** Mac mini M4.

If you see **"Failed to query provider ... Get \"https://hardy-mac-mini.folk-adelie.ts.net/application/o/argocd/.well-known/openid-configuration\": EOF"** when logging into Argo CD with Authentik, the **Argo CD server pod** (inside the cluster) cannot reach that URL because the Tailscale hostname does not resolve to Authentik from inside the cluster.

**Fix (recommended): hostAlias + OIDC Service (port 8444)** — no CoreDNS needed. The repo is already set up for this:

1. **OIDC Service** (`k8s/apps/authentik/oidc-service.yaml`) exposes port **8444** so in-cluster clients can reach Authentik OIDC. It uses ClusterIP `10.43.50.101` (OrbStack/K3s). For 10.96.x clusters, change that file's `clusterIP` to `10.96.50.101` and set the variable below to match.
2. **Terraform** adds a `hostAlias` so that `hardy-mac-mini.folk-adelie.ts.net` resolves to that IP (`authentik_oidc_host_alias_ip`, default `10.43.50.101`).

**Cách biết cluster dùng dải IP nào:** Chạy `kubectl get svc -A | head -20` và xem cột **CLUSTER-IP**. Chọn IP trong cùng dải, ví dụ: `10.43.x.x` → `10.43.50.101`; `10.96.x.x` → `10.96.50.101`; **`192.168.194.x`** → sửa `oidc-service.yaml` thành `clusterIP: "192.168.194.101"` và trong tfvars đặt `authentik_oidc_host_alias_ip = "192.168.194.101"`.


**If you see "dial tcp …:8444: i/o timeout"**: ensure the OIDC Service exists and Terraform points to it. Sync the `authentik-config` app (it deploys `oidc-service.yaml`), then set in `terraform/terraform.tfvars`: `authentik_oidc_host_alias_ip = "10.43.50.101"` (or `10.96.50.101` for 10.96.x), run `terraform apply`, and restart Argo CD server.

**Apply and restart:**

```bash
# On Mac mini: apply Terraform (updates Argo CD hostAliases)
cd homelab/terraform
terraform apply

# Wait for Argo CD to sync the Authentik app (so Authentik service gets the fixed ClusterIP if you changed it)
kubectl get applications -n argocd -w
# Ctrl+C when authentik is Synced/Healthy

# Restart Argo CD server so pods pick up the new hostAlias
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

Then retry **Login via Authentik** in Argo CD.

**Verify from inside the cluster (optional):**

```bash
# Resolve hostname from a temporary pod (should get the alias IP)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -sI "https://hardy-mac-mini.folk-adelie.ts.net/application/o/argocd/.well-known/openid-configuration" -k
# Expect HTTP 200 or 301, not connection error.
```

**Fallback — CoreDNS rewrite:** If you prefer not to use the fixed ClusterIP, you can make the hostname resolve via CoreDNS (see repo history for the previous Step 7b text) and remove `global.hostAliases` from Terraform and `clusterIP` from the Authentik app.

---

## 7c. Troubleshooting: Argo CD login via Authentik still fails (checklist)

**Where:** Mac mini M4. Run these in order and fix any step that fails.

### 1. Terraform: hostAliases đã được áp vào Argo CD chưa?

```bash
cd homelab/terraform
terraform plan
```

Trong plan phải thấy `helm_release.argocd` với thay đổi liên quan `global.hostAliases` (hoặc đã apply rồi thì không còn thay đổi). Nếu không thấy: kiểm tra `variables.tf` có biến `authentik_oidc_host_alias_ip`, `argocd.tf` có block `set { name = "global.hostAliases" ... }`, và `terraform.tfvars` có `tailscale_host` (và nếu cần thì `authentik_oidc_host_alias_ip`). Rồi chạy lại `terraform apply`.

### 2. Argo CD server có hostAlias không?

**Cách 1 — Xem từ Deployment (template mà Helm áp):**

```bash
kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.hostAliases}' | jq .
```

Nếu có hostAlias, sẽ thấy dạng: `[{"ip":"10.96.50.100","hostnames":["hardy-mac-mini.folk-adelie.ts.net"]}]`. Nếu ra `null` hoặc `[]`: Terraform chưa áp hostAliases lên Helm release (kiểm tra bước 1, rồi `terraform apply` và restart deployment).

**Cách 2 — Xem từ pod (sau khi đã restart):**

```bash
# Liệt kê pod trong namespace argocd (để biết tên / label)
kubectl get pods -n argocd

# Lấy hostAliases từ pod của deployment argocd-server (theo tên deployment)
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.hostAliases}' | jq .

# Hoặc nếu label khác, dùng tên deployment trực tiếp:
kubectl get pods -n argocd -o name | grep argocd-server | head -1 | xargs -I {} kubectl get {} -n argocd -o jsonpath='{.spec.hostAliases}' | jq .
```

Kỳ vọng: có 1 entry với `ip` = IP bạn dùng và `hostnames` chứa `hardy-mac-mini.folk-adelie.ts.net`. Nếu không thấy gì: chạy lại `terraform apply`, rồi `kubectl rollout restart deployment argocd-server -n argocd` và đợi pod mới Ready, kiểm tra lại.

### 3. OIDC Service (port 8444) có đúng ClusterIP không?

```bash
kubectl get svc -n authentik authentik-server-oidc -o wide
kubectl get svc -n authentik -l app.kubernetes.io/component=server -o wide
```

`authentik-server-oidc` phải có **CLUSTER-IP** trùng với `authentik_oidc_host_alias_ip` trong tfvars (vd. `10.43.50.101` cho OrbStack/K3s, `10.96.50.101` cho 10.96.x). Nếu thiếu Service này, sync app **authentik-config** (nó deploy `oidc-service.yaml`). Nếu CLUSTER-IP của `authentik-server-oidc` khác với tfvars: sửa `k8s/apps/authentik/oidc-service.yaml` (field `clusterIP`) cho đúng dải của cluster (vd. `10.43.50.101` hoặc `10.96.50.101`), push, sync authentik-config, rồi trong `terraform.tfvars` đặt `authentik_oidc_host_alias_ip` trùng với ClusterIP đó, chạy `terraform apply` và restart Argo CD server.

### 4. Từ trong cluster có gọi được OIDC discovery không?

Dùng đúng **authentik_base_url** (có port, vd. :8444):

```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -sI "https://hardy-mac-mini.folk-adelie.ts.net:8444/application/o/argocd/.well-known/openid-configuration" -k
```

Kỳ vọng: HTTP/1.1 200 hoặc 301. Nếu `Connection refused` hoặc timeout: hostAlias sai IP, hoặc Service Authentik chưa expose port 8444 (patch ở Step 7), hoặc pod chưa restart. Nếu lỗi chứng chỉ nhưng vẫn có response: Argo CD thường chấp nhận với cấu hình mặc định.

### 5. Dải IP dịch vụ (service CIDR) của cluster

Nếu cluster dùng 10.96.x.x thay vì 10.43.x.x: trong `k8s/apps/authentik/oidc-service.yaml` đặt `clusterIP: "10.96.50.101"`, trong `terraform.tfvars` đặt `authentik_oidc_host_alias_ip = "10.96.50.101"`, push, sync authentik-config, rồi `terraform apply` và restart Argo CD server.

### 6. Authentik: OIDC provider và redirect URI

Trong Authentik Admin: **Applications → Providers** → provider cho Argo CD (client_id `argocd`). Redirect URI phải là:

`https://hardy-mac-mini.folk-adelie.ts.net:8443/auth/callback`

Nếu sai hoặc thiếu, sửa và thử login lại.

### 7. Restart Argo CD server sau mọi thay đổi Terraform

Sau khi `terraform apply` (đổi hostAliases), luôn restart để pod nhận spec mới:

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

### 8. Argo CD vẫn không login được — checklist nhanh

Chạy lần lượt trên **Mac mini**:

**A. Argo CD đang dùng issuer có port :8444 chưa?**

```bash
kubectl get cm argocd-cm -n argocd -o yaml | grep -A 20 oidc
```

Phải thấy `issuer: https://hardy-mac-mini.folk-adelie.ts.net:8444/application/o/argocd/`. Nếu vẫn là URL không port hoặc sai port → thêm `authentik_base_url = "https://hardy-mac-mini.folk-adelie.ts.net:8444"` vào `terraform.tfvars`, chạy `terraform apply`, rồi restart deployment `argocd-server`.

**B. Pod có gọi được discovery qua :8444 không?**

```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -sk "https://hardy-mac-mini.folk-adelie.ts.net:8444/application/o/argocd/.well-known/openid-configuration" | head -5
```

Phải ra JSON (có `"issuer"`, `"authorization_endpoint"`). Nếu connection refused → Service Authentik chưa expose 8444: chạy patch [ở Step 7](#7-tailscale-serve-mac-mini-m4) (patch svc authentik thêm port 8444). Rồi kiểm tra lại hostAlias (bước 2) và restart `argocd-server`.

**C. Trong Authentik: Provider Argo CD**

- Vào **Authentik** → **Applications** → **Providers** → mở provider dùng cho Argo CD.
- **Client ID** phải là `argocd`.
- **Redirect URIs** phải có đúng một dòng: `https://hardy-mac-mini.folk-adelie.ts.net:8443/auth/callback` (không thêm port 8444, không thiếu `https://`, không thừa dấu `/` cuối).
- **Client secret**: giá trị phải trùng với secret đang dùng trong Terraform (biến `argocd_oidc_client_secret` / secret `argocd-secret`). Nếu đổi secret bên Authentik thì cập nhật `terraform.tfvars` và chạy `terraform apply`, rồi restart `argocd-server`.

**D. Application trong Authentik**

- **Applications** → app dùng cho Argo CD → **Provider** phải trỏ đúng provider có client_id `argocd` (bước C).

**E. Restart Argo CD server**

Sau mọi thay đổi cấu hình (Terraform hoặc Authentik):

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

Sau đó mở Argo CD (`https://hardy-mac-mini.folk-adelie.ts.net:8443`), bấm **Login via Authentik** và xem message lỗi (nếu có) trên trang Argo CD hoặc trong log `argocd-server`.

---

## 8. OpenClaw hostPath (Mac mini M4)

**Where:** Mac mini M4, only if your repo is **not** at `/Users/<your-username>/homelab`.

The OpenClaw deployment mounts two hostPaths. If you cloned the repo to a different path (e.g. `/Users/jane/Projects/homelab`), edit the deployment once:

```bash
cd homelab
# Edit k8s/apps/openclaw/deployment.yaml
# Replace /Users/holden.nguyen/homelab with your actual path, e.g. /Users/jane/Projects/homelab
# in both:
#   - name: workspace-src  → hostPath.path
#   - name: openclaw-skills → hostPath.path
```

If you cloned to `~/homelab`, then on the Mac mini `~/homelab` resolves to `/Users/<username>/homelab`. So you only need to change `holden.nguyen` to your Mac username in both `hostPath.path` fields (e.g. `/Users/jane/homelab/agents/workspaces` and `/Users/jane/homelab/skills`).

Commit and push this change (via a branch/PR if you follow the repo’s git workflow).

---

## 9. Build OpenClaw Image (Mac mini M4)

**Where:** Mac mini M4, repo root. Requires Docker (OrbStack) and the `openclaw` submodule (Step 1).

```bash
cd homelab
./scripts/build-openclaw.sh
```

This builds `openclaw:base` from the submodule, then the homelab overlay as `openclaw:latest`. To use a custom tag:

```bash
./scripts/build-openclaw.sh openclaw:v1.0.0
# Then set the same image in k8s/apps/openclaw/deployment.yaml image: field
```

---

## 10. Verify Full Deployment (Mac mini M4)

**Where:** Mac mini M4.

The App of Apps may still include a **monitoring** (Grafana) application. If you do not want it, in Argo CD UI (`https://hardy-mac-mini.folk-adelie.ts.net:8443`) open the `monitoring` app and delete it or set **Sync Policy** to disabled.

```bash
# All Argo CD apps should become Synced + Healthy (may take several minutes)
kubectl get applications -n argocd

# No stuck or failing pods (list non-Running/non-Completed)
kubectl get pods -A | grep -v Running | grep -v Completed

# ExternalSecrets synced
kubectl get externalsecret -A
```

If OpenClaw ExternalSecret is not synced, force refresh:

```bash
kubectl annotate externalsecret openclaw-secret -n openclaw force-sync=$(date +%s) --overwrite
```

---

## 11. OpenClaw Device Pairing (Mac mini M4 + Browser)

**Where:** Browser (via Tailscale URL) and Mac mini (kubectl).

1. Open the OpenClaw Control UI: `https://hardy-mac-mini.folk-adelie.ts.net:8447` (or from **hardy-iphone** on the same tailnet)
2. In settings, enter `OPENCLAW_GATEWAY_TOKEN` (from Infisical, or from cluster: `kubectl get secret openclaw-secret -n openclaw -o jsonpath='{.data.OPENCLAW_GATEWAY_TOKEN}' | base64 -d`) and click Connect.
3. If you see “pairing required”, on the Mac mini:

   ```bash
   kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices list
   kubectl exec -n openclaw deploy/openclaw -- node dist/index.js devices approve <requestId>
   ```

4. Connect again from the UI.

---

## 12. Optional: Nightly Shutdown/Startup (Mac mini M4)

**Where:** Mac mini M4. See [Nightly Shutdown](../operations/nightly-shutdown.md) for full detail.

- Scripts: `scripts/orb-stop.sh`, `scripts/orb-start.sh`
- launchd plists: `scripts/com.homelab.orbstop.plist`, `scripts/com.homelab.orbstart.plist`
- Install under `~/Library/LaunchAgents/` and load so the cluster stops at 23:30 and starts at 06:30.

---

## Quick Reference: Where to Run What

| Step | Where | What |
|------|--------|------|
| 0 | Mac mini M4 | Install OrbStack, kubectl, terraform, helm, Docker, Tailscale, git; enable K8s |
| 1 | Mac mini M4 | `git clone` + `git submodule update --init` |
| 2 | Mac mini M4 | `openssl rand` (save outputs) |
| 3 | Mac mini M4 | `cp terraform.tfvars.example terraform.tfvars` and edit |
| 4 | Mac mini M4 | `cd terraform && terraform init && terraform apply` |
| 5 | Mac mini M4 | `kubectl get pods -n infisical -w` until Ready |
| 6 | Browser + Mac mini | Infisical: create project, secrets, Machine Identity; update tfvars; `terraform apply` |
| 7 | Mac mini M4 | `tailscale serve --bg ...` (no Grafana; base URL hardy-mac-mini.folk-adelie.ts.net) |
| 7b | Mac mini M4 | If Argo CD login via Authentik gives EOF: hostAlias + fixed ClusterIP; apply Terraform, restart argocd-server |
| 7c | Mac mini M4 | If still fails: run [Troubleshooting checklist](#7c-troubleshooting-argocd-login-via-authentik-still-fails-checklist) (hostAlias, ClusterIP, delete Service if needed) |
| 8 | Mac mini M4 | Edit `k8s/apps/openclaw/deployment.yaml` hostPath if path differs |
| 9 | Mac mini M4 | `./scripts/build-openclaw.sh` |
| 10 | Mac mini M4 | `kubectl get applications -n argocd`, `kubectl get externalsecret -A` |
| 11 | Browser + Mac mini | OpenClaw UI + `devices approve` |
| 12 | Mac mini M4 | Optional launchd for orb-stop / orb-start |

---

## See Also

- [Bootstrap Guide](bootstrap.md) — same flow with more narrative and troubleshooting
- [Architecture](architecture.md) — layers, services, and repo layout
- [Secret Management](../infrastructure/secret-management.md) — adding/rotating secrets
- [OpenClaw README](../../k8s/apps/openclaw/README.md) — Discord, models, agents, and CLI
