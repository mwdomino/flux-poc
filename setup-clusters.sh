#!/usr/bin/env bash

set -e

echo "Creating Kind clusters..."

# Create core cluster (management cluster with FluxCD)
echo "Creating core cluster..."
kind create cluster --name core --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF

# Create prod cluster
echo "Creating prod cluster..."
kind create cluster --name prod --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF

# Create stage cluster
echo "Creating stage cluster..."
kind create cluster --name stage --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF

echo "All clusters created successfully!"
echo "Available clusters:"
kind get clusters

echo "Installing FluxCD on core cluster..."
kubectl config use-context kind-core

# Install Flux CLI if not present
if ! command -v flux &> /dev/null; then
    echo "Installing Flux CLI..."
    curl -s https://fluxcd.io/install.sh | sudo bash
fi

# Bootstrap Flux on core cluster
echo "Bootstrapping Flux on core cluster..."
flux install

echo "Setup complete! Core cluster has FluxCD installed."
echo "Switch between clusters with:"
echo "  kubectl config use-context kind-core"
echo "  kubectl config use-context kind-prod" 
echo "  kubectl config use-context kind-stage"
