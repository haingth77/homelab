#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="${1:-openclaw:latest}"
BASE_IMAGE="openclaw:base"

echo "==> Building OpenClaw base image: ${BASE_IMAGE}"
echo "    Context: ${REPO_ROOT}/openclaw"

docker build \
  --platform linux/arm64 \
  -t "${BASE_IMAGE}" \
  "${REPO_ROOT}/openclaw"

echo ""
echo "==> Building homelab overlay image: ${IMAGE_NAME}"
echo "    Dockerfile: ${REPO_ROOT}/Dockerfile.openclaw"

docker build \
  --platform linux/arm64 \
  -t "${IMAGE_NAME}" \
  -f "${REPO_ROOT}/Dockerfile.openclaw" \
  "${REPO_ROOT}"

echo ""
echo "Image built successfully: ${IMAGE_NAME}"
echo "  Includes: kubectl, helm, terraform, argocd, jq"
echo ""
echo "Next steps:"
echo "  - If this is the first deploy, push k8s manifests to main and wait for ArgoCD sync"
echo "  - If updating an existing deploy: kubectl rollout restart deployment/openclaw -n openclaw"
