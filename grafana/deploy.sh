#!/bin/bash
set -e

echo "📊 Deploying Grafana..."

# Create namespace
echo "📁 Creating grafana namespace..."
kubectl create namespace grafana --dry-run=client -o yaml | kubectl apply -f -

# Apply datasources configuration
echo "🔗 Creating Grafana datasources..."
kubectl apply -f grafana/datasources.yaml

# Add Grafana Helm repository
echo "📦 Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy Grafana
echo "🚀 Installing Grafana with Helm..."
helm upgrade --install grafana grafana/grafana \
    --namespace grafana \
    --values grafana/values.yaml \
    --wait \
    --timeout 5m

# Apply ingress
echo "🌐 Creating Grafana ingress..."
kubectl apply -f grafana/ingress.yaml

echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n grafana --timeout=300s

# Get admin password
GRAFANA_PASSWORD=$(kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "✅ Grafana deployed successfully!"
echo "📝 Access info:"
echo "   URL: http://grafana.localhost"
echo "   Username: admin"
echo "   Password: $GRAFANA_PASSWORD"