# Argo CD Deployment for Kubernetes (GitOps)

This directory contains the Kustomization definition for deploying Argo CD to your Kubernetes cluster. Argo CD is a declarative GitOps continuous delivery tool for Kubernetes.

## Overview

This setup uses Kustomize to fetch and apply the official Argo CD installation manifests directly from the `argoproj/argo-cd` GitHub repository. This ensures you are always deploying a stable and officially supported version of Argo CD.

## Components

- `kustomization.yaml`: This file references the upstream Argo CD `install.yaml` manifest. It can also be extended to include overlays or patches for customizing the Argo CD deployment (e.g., changing service types, adding resource limits).

## Deployment using GitOps

Once your homelab GitOps repository is set up with a GitOps agent (which will be Argo CD itself, creating a bootstrap paradox we'll manage), any changes pushed to this `k8s/apps/argocd` directory will trigger Argo CD to deploy or update itself in the Kubernetes cluster.

## Initial Access to Argo CD

After Argo CD is deployed by applying these manifests (initially via `kubectl apply -k k8s/apps/argocd` or by a temporary Argo CD instance), you will need to:

1.  **Access the Argo CD UI:**
    By default, the `argocd-server` service is of type `ClusterIP`. To access the UI, you can port-forward:
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    # Then open https://localhost:8080 in your browser
    ```
    Alternatively, you can patch the `argocd-server` service to `NodePort` or `LoadBalancer` (as commented out in `kustomization.yaml` example) or configure an Ingress.

2.  **Login with Initial Password:**
    The initial password for the `admin` user is automatically generated and stored in a Kubernetes Secret. Retrieve it using:
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```
    Use `admin` as the username and the retrieved password to log in.

## Next Steps with Argo CD

Once Argo CD is running, you will create an Argo CD `Application` resource that points to *this* GitOps repository (`/homelab`) and specifically to the `k8s/apps/gitea` path to deploy Gitea.
