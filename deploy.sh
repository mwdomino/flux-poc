#!/usr/bin/env bash

set -e

echo "🚀 Starting Flux POC deployment..."

# Step 1: Initialize git repo if not already done
if [ ! -d .git ]; then
    echo "📦 Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial Flux POC setup"
fi

# Step 2: Create Kind clusters and install Flux
echo "🔧 Setting up Kind clusters and FluxCD..."
./setup-clusters.sh

# Step 3: Set up multi-cluster kubeconfig secrets
echo "🔗 Setting up multi-cluster management..."
./setup-multi-cluster.sh

# Step 4: Bootstrap Flux with local repository
echo "📋 Bootstrapping Flux with local GitOps repository..."
kubectl config use-context kind-core

# Bootstrap Flux to watch this local repo
flux bootstrap git \
  --url=file://$(pwd) \
  --branch=main \
  --path=clusters/core

echo "✅ Deployment complete!"
echo ""
echo "🔍 Flux will automatically apply all configurations from the Git repository."
echo "Check status with:"
echo "  flux get kustomizations"
echo "  kubectl get dragonflydb -A"
echo ""
echo "🔄 Switch between clusters:"
echo "  kubectl config use-context kind-core"
echo "  kubectl config use-context kind-prod"
echo "  kubectl config use-context kind-stage"