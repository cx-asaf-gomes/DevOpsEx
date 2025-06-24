#!/bin/bash
set -e

echo "🐘 Deploying PostgreSQL..."

# Create namespace
echo "📁 Creating postgres namespace..."
kubectl create namespace postgres --dry-run=client -o yaml | kubectl apply -f -

# Create secret
echo "🔐 Creating PostgreSQL secret..."
kubectl apply -f postgres/secret.yaml

# Add Bitnami Helm repository
echo "📦 Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy PostgreSQL
echo "🚀 Installing PostgreSQL with Helm..."
helm upgrade --install postgresql bitnami/postgresql \
    --namespace postgres \
    --values postgres/values.yaml \
    --wait \
    --timeout 5m

# Apply ingress
echo "🌐 Creating PostgreSQL ingress..."
kubectl apply -f postgres/ingress.yaml

echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgres --timeout=300s

echo "✅ PostgreSQL deployed successfully!"
echo "📝 Connection info:"
echo "   Host: postgresql.postgres.svc.cluster.local"
echo "   Port: 5432"
echo "   Database: postgres"
echo "   Username: admin"
echo "   Password: admin123"
echo "   External URL: http://postgres.localhost (if needed)"