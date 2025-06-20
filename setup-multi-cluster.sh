#!/usr/bin/env bash

set -e

echo "Setting up multi-cluster management..."

# Ensure we're on the core cluster
kubectl config use-context kind-core

echo "Creating kubeconfig secrets for remote clusters..."

# Get prod cluster kubeconfig and create secret
echo "Setting up prod cluster kubeconfig secret..."
kind get kubeconfig --name prod > /tmp/prod-kubeconfig
kubectl create secret generic prod-cluster-kubeconfig \
  --from-file=value=/tmp/prod-kubeconfig \
  --namespace=flux-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Get stage cluster kubeconfig and create secret  
echo "Setting up stage cluster kubeconfig secret..."
kind get kubeconfig --name stage > /tmp/stage-kubeconfig
kubectl create secret generic stage-cluster-kubeconfig \
  --from-file=value=/tmp/stage-kubeconfig \
  --namespace=flux-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Clean up temp files
rm /tmp/prod-kubeconfig /tmp/stage-kubeconfig

echo "Multi-cluster kubeconfig secrets created successfully!"
echo "Flux can now manage prod and stage clusters from core cluster."