#!/bin/bash
set -e

CLUSTER_NAME="devops-cluster"

echo "🔍 Checking if cluster already exists..."
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "✅ Cluster '$CLUSTER_NAME' already exists."
else
    echo "🏗️ Creating K3d cluster with Traefik..."
    k3d cluster create $CLUSTER_NAME \
        --servers 1 \
        --agents 2 \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --volume "$(pwd)/k3d-volumes:/var/lib/rancher/k3s/storage@all" \
        --k3s-arg "--disable=metrics-server@server:*" \
        --wait
    
    echo "✅ Cluster created successfully!"
fi

# Export kubeconfig
export KUBECONFIG=$(k3d kubeconfig write $CLUSTER_NAME)

# Just a brief pause to let things stabilize
echo "⏳ Letting cluster stabilize..."
sleep 5

# Show cluster status without waiting
echo "📊 Cluster status:"
kubectl get nodes
echo ""
kubectl get pods -n kube-system || true

echo "📊 Cluster nodes:"
kubectl get nodes

echo "🎯 Cluster is ready!"