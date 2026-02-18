#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="${1:-openclaw:latest}"

echo "Building OpenClaw Docker image: ${IMAGE_NAME}"
echo "Context: ${REPO_ROOT}/openclaw"

docker build \
  --platform linux/arm64 \
  -t "${IMAGE_NAME}" \
  "${REPO_ROOT}/openclaw"

echo ""
echo "Image built successfully: ${IMAGE_NAME}"
echo ""
echo "Next steps:"
echo "  - If this is the first deploy, push k8s manifests to main and wait for ArgoCD sync"
echo "  - If updating an existing deploy: kubectl rollout restart deployment/openclaw -n openclaw"
