# Gitea Deployment for Kubernetes (GitOps)

This directory contains the Kubernetes manifests for deploying a self-hosted Gitea instance to your Kubernetes cluster using GitOps principles.

## Overview

Gitea is deployed as a single pod with a Persistent Volume Claim for data storage (repositories, database). Its configuration is managed via a ConfigMap, and sensitive information like the `SECRET_KEY` is handled via a Kubernetes Secret. Network access is provided via a Service and an Ingress.

**Note:** This Gitea deployment now utilizes a separate PostgreSQL instance for its database backend. Refer to the `../postgresql/README.md` for details on the PostgreSQL setup.

## Components

- `namespace.yaml`: Defines the `gitea-system` namespace for Gitea resources.
- `pvc.yaml`: Creates a Persistent Volume Claim (`gitea-data`) for Gitea's data.
- `configmap.yaml`: Contains the `app.ini` configuration for Gitea, now configured for PostgreSQL.
- `secret.yaml`: Stores sensitive data, specifically the `GITEA_SECRET_KEY` and `GITEA_DB_PASSWORD` (for connecting to PostgreSQL). The `GITEA_SECRET_KEY` value has been replaced with a random base64 encoded string.
- `deployment.yaml`: Defines the Gitea server Deployment, including container image, environment variables (now configured for PostgreSQL connection), resource limits, and volume mounts.
- `service.yaml`: Exposes the Gitea HTTP (port 3000) and SSH (port 22) services internally within the cluster.
- `ingress.yaml`: Configures external access to Gitea via HTTPS with `gitea.homelab.local` and forces SSL redirection.

## Deployment using GitOps

Once Argo CD (or your chosen GitOps tool) is configured to monitor this repository (specifically the `k8s/apps/gitea` path), it will automatically deploy these resources to your Kubernetes cluster.

## Post-Deployment

1.  **Initialize Gitea:** Access Gitea via the Ingress URL (`https://gitea.homelab.local`). You will be guided through the initial setup. Ensure the root URL is correctly configured during this step.
2.  **SSH Access:** If you plan to use SSH for Git operations, ensure port 22 is correctly exposed through your Kubernetes setup (e.g., NodePort or LoadBalancer for the SSH service, or an Ingress controller configured for SSH).
3.  **Backup Strategy:** Implement a robust backup strategy for your Gitea data (the `gitea-data` PVC) and the PostgreSQL database.
