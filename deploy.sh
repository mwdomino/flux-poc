#!/usr/bin/env bash

set -e

echo "🚀 Starting Flux POC deployment..."

# Step 1: Initialize git repo and push to GitHub
if [ ! -d .git ]; then
    echo "📦 Initializing Git repository..."
    git init
    git remote add origin https://github.com/mwdomino/flux-poc.git
fi

echo "📤 Pushing to GitHub repository..."
git add .
git commit -m "Initial Flux POC setup" || echo "No changes to commit"
git push --force-with-lease origin main || git push --set-upstream origin main --force

# Step 2: Create Kind clusters and install Flux
# echo "🔧 Setting up Kind clusters and FluxCD..."
# ./setup-clusters.sh
#
# # Step 3: Set up multi-cluster kubeconfig secrets
# echo "🔗 Setting up multi-cluster management..."
# ./setup-multi-cluster.sh
# Step 4: Bootstrap Flux with local repository
echo "📋 Bootstrapping Flux with local GitOps repository..."
kubectl config use-context kind-core

# Bootstrap Flux with GitHub repository
flux bootstrap github \
  --owner=mwdomino \
  --repository=flux-poc \
  --branch=main \
  --path=clusters/core \
  --personal

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
