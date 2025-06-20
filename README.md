# Flux GitOps Multi-Cluster POC

This repository demonstrates a GitOps approach using FluxCD to manage multiple Kubernetes clusters from a single management cluster.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Core Cluster  │────▶│  Prod Cluster   │     │  Stage Cluster  │
│  (Management)   │     │                 │     │                 │
│                 │     │                 │     │                 │
│ ┌─────────────┐ │     │ ┌─────────────┐ │     │ ┌─────────────┐ │
│ │   FluxCD    │ │     │ │  Dragonfly  │ │     │ │  Dragonfly  │ │
│ │             │ │     │ │  Operator   │ │     │ │  Operator   │ │
│ └─────────────┘ │     │ │ + Instance  │ │     │ │ + Instance  │ │
│ ┌─────────────┐ │     │ └─────────────┘ │     │ └─────────────┘ │
│ │  Dragonfly  │ │     └─────────────────┘     └─────────────────┘
│ │  Operator   │ │              ▲                        ▲
│ │ + Instance  │ │              │                        │
│ └─────────────┘ │              │                        │
└─────────────────┘              │                        │
         │                       │                        │
         └───────────────────────┴────────────────────────┘
                    GitOps Management via kubeconfig secrets
```

## Components

- **Core Cluster**: Management cluster running FluxCD that orchestrates deployments to all clusters
- **Prod/Stage Clusters**: Target clusters managed remotely via kubeconfig secrets
- **Dragonfly Operator**: Redis-compatible in-memory datastore operator deployed to all clusters
- **Kustomize Overlays**: Cluster-specific configurations using Kustomize patches

## Quick Start

### Prerequisites

- Docker
- Kind
- kubectl
- Flux CLI
- Git
- GitHub token with repo permissions (set as `GITHUB_TOKEN` environment variable)

### Deploy Everything

```bash
# Clone and deploy
git clone https://github.com/mwdomino/flux-poc.git
cd flux-poc
./deploy.sh
```

### Manual Setup (Alternative)

If you prefer step-by-step setup:

```bash
# 1. Create Kind clusters
./setup-clusters.sh

# 2. Setup multi-cluster management
./setup-multi-cluster.sh

# 3. Bootstrap Flux (requires GITHUB_TOKEN)
kubectl config use-context kind-core
flux bootstrap github \
  --owner=mwdomino \
  --repository=flux-poc \
  --branch=main \
  --path=clusters/core \
  --personal
```

## Directory Structure

```
├── clusters/
│   ├── core/                    # Core cluster configurations
│   │   ├── infrastructure.yaml  # Core cluster Dragonfly deployment
│   │   ├── prod-cluster.yaml    # Prod cluster remote management
│   │   └── stage-cluster.yaml   # Stage cluster remote management
│   ├── prod/                    # Prod cluster configurations (unused - managed remotely)
│   └── stage/                   # Stage cluster configurations (unused - managed remotely)
│
├── infrastructure/
│   ├── base/
│   │   └── dragonfly/
│   │       ├── namespace.yaml        # Dragonfly operator namespace
│   │       ├── operator.yaml         # Dragonfly operator manifest
│   │       ├── dragonfly-instance.yaml # Base Dragonfly instance
│   │       └── kustomization.yaml    # Base kustomization
│   │
│   └── overlays/
│       ├── core/
│       │   └── dragonfly/
│       │       ├── kustomization.yaml     # Core overlay
│       │       └── dragonfly-patch.yaml   # Core-specific patches
│       ├── prod/
│       │   └── dragonfly/
│       │       ├── kustomization.yaml     # Prod overlay  
│       │       └── dragonfly-patch.yaml   # Prod-specific patches
│       └── stage/
│           └── dragonfly/
│               ├── kustomization.yaml     # Stage overlay
│               └── dragonfly-patch.yaml   # Stage-specific patches
│
├── setup-clusters.sh           # Creates Kind clusters and installs Flux
├── setup-multi-cluster.sh      # Sets up kubeconfig secrets for remote management
└── deploy.sh                   # Complete deployment script
```

## How It Works

### 1. Cluster Creation
- Three Kind clusters are created: `core`, `prod`, `stage`
- Each cluster has a single control-plane node
- FluxCD is installed only on the core cluster

### 2. Multi-Cluster Management
- Core cluster manages remote clusters using kubeconfig secrets
- Docker container IPs are used instead of localhost for cross-cluster communication
- Secrets contain kubeconfig files with corrected server endpoints

### 3. GitOps Deployment Flow
1. **Git Push**: Changes pushed to GitHub repository
2. **Flux Sync**: Core cluster FluxCD syncs from repository
3. **Local Deploy**: Core cluster deploys its own infrastructure
4. **Remote Deploy**: Core cluster deploys to prod/stage via kubeconfig secrets
5. **Reconciliation**: Flux continuously monitors and applies changes

### 4. Kustomize Structure
- **Base**: Common Dragonfly operator and instance configuration
- **Overlays**: Cluster-specific patches for resource limits, passwords, etc.
- **Patches**: Strategic merge patches modify base configurations per environment

## Verification

Check deployment status:

```bash
# Check Flux status
kubectl config use-context kind-core
flux get kustomizations

# Check Dragonfly deployments on all clusters
kubectl get pods -A --context kind-core
kubectl get pods -A --context kind-prod  
kubectl get pods -A --context kind-stage

# Check Dragonfly instances
kubectl get dragonfly -A --context kind-core
kubectl get dragonfly -A --context kind-prod
kubectl get dragonfly -A --context kind-stage
```

## Adding a New Cluster

To add a new cluster (e.g., `dev`):

### 1. Create the Kind Cluster

```bash
kind create cluster --name dev --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF
```

### 2. Create Infrastructure Overlay

```bash
# Create directory structure
mkdir -p infrastructure/overlays/dev/dragonfly

# Create kustomization
cat > infrastructure/overlays/dev/dragonfly/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../base/dragonfly

patchesStrategicMerge:
  - dragonfly-patch.yaml
EOF

# Create cluster-specific patch
cat > infrastructure/overlays/dev/dragonfly/dragonfly-patch.yaml <<EOF
apiVersion: dragonflydb.io/v1alpha1
kind: Dragonfly
metadata:
  name: dragonfly-sample
  namespace: default
spec:
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
EOF

# Create overlay kustomization
cat > infrastructure/overlays/dev/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - dragonfly
EOF
```

### 3. Create Multi-Cluster Management

```bash
# Add to core cluster management
cat > clusters/core/dev-cluster.yaml <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-dev
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./infrastructure/overlays/dev"
  prune: true
  wait: true
  kubeConfig:
    secretRef:
      name: dev-cluster-kubeconfig
EOF
```

### 4. Setup Kubeconfig Secret

```bash
# Switch to core cluster
kubectl config use-context kind-core

# Get dev cluster kubeconfig and fix server URL
kind get kubeconfig --name dev > /tmp/dev-kubeconfig
DEV_IP=$(docker inspect dev-control-plane | grep '"IPAddress"' | tail -1 | sed 's/.*: "//; s/",//')
sed -i "s|server: https://127.0.0.1:[0-9]*|server: https://${DEV_IP}:6443|" /tmp/dev-kubeconfig

# Create secret
kubectl create secret generic dev-cluster-kubeconfig \
  --from-file=value=/tmp/dev-kubeconfig \
  --namespace=flux-system

# Clean up
rm /tmp/dev-kubeconfig
```

### 5. Commit and Push

```bash
git add .
git commit -m "Add dev cluster configuration"
git push origin main
```

Flux will automatically detect the changes and deploy to the new cluster within a few minutes.

## Cleanup

Remove all clusters:

```bash
kind delete clusters core prod stage
```

## Troubleshooting

### Common Issues

1. **Connection Refused Errors**: Usually indicates kubeconfig secrets have wrong endpoints
   - Solution: Run `./setup-multi-cluster.sh` to refresh secrets

2. **CrashLoopBackOff on Dragonfly Instances**: Resource constraints or configuration issues
   - Solution: Check logs with `kubectl logs <pod-name>` and adjust resource limits

3. **Kustomization Not Applied**: Flux may not have detected changes
   - Solution: Force reconciliation with `flux reconcile kustomization <name>`

### Useful Commands

```bash
# Force Flux to sync immediately
flux reconcile source git flux-system

# Check Flux logs
kubectl logs -n flux-system -l app=source-controller
kubectl logs -n flux-system -l app=kustomize-controller

# Debug multi-cluster connectivity
kubectl exec -n flux-system deploy/kustomize-controller -- kubectl --kubeconfig=/tmp/kubeconfig get nodes
```