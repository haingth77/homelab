# Hello World - Homelab Demo

A minimal Go web application demonstrating containerized deployment on Kubernetes.

## Features

- Serves a friendly HTML page at `/`
- Health check endpoint at `/health` (returns JSON `{"status":"ok"}`)
- Lightweight (~10MB container image)
- Production-ready with liveness/readiness probes

## Local Development

### Prerequisites

- Go 1.22+
- Docker

### Build and Run Locally

```bash
# Build binary
go build -o hello-world .

# Run
./hello-world
# Visit http://localhost:8080
```

### Docker

```bash
# Build image
docker build -t hello-world:latest .

# Run container
docker run -p 8080:8080 hello-world:latest
# Visit http://localhost:8080
```

## Kubernetes Deployment

### Build and Push Image

```bash
# Build
docker build -t hello-world:latest .

# Tag for your registry (example)
docker tag hello-world:latest myregistry.example.com/hello-world:latest

# Push
docker push myregistry.example.com/hello-world:latest
```

Update `manifests/deployment.yaml` to use your image path.

### Deploy

```bash
# Create namespace if desired (optional)
kubectl create namespace hello-world

# Apply manifests
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml

# Optional: If you have an ingress controller
kubectl apply -f manifests/ingress.yaml
```

### Access

- **NodePort**: `http://<node-ip>:30080`
- **Ingress**: `http://hello.homelab.local` (configure DNS/hosts)

### Verify

```bash
kubectl get pods,svc,ingress
kubectl port-forward svc/hello-world 8080:80
curl http://localhost:8080/health
```

## Cleanup

```bash
kubectl delete -f manifests/
```

## Notes

- The Go binary embeds `index.html` using `//go:embed`.
- Resource requests/limits are intentionally minimal.
- Health check returns 200 on `/health`.