#!/bin/bash
set -e

echo "🔧 Deploying Jenkins with automatic job creation..."

# Create namespace
echo "📁 Creating jenkins namespace..."
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Apply RBAC first
echo "🔐 Applying Jenkins RBAC..."
kubectl apply -f jenkins/rbac.yaml

# Create secrets
echo "🔐 Creating Jenkins secret..."
kubectl apply -f jenkins/secret.yaml

# Add Jenkins Helm repository
echo "📦 Adding Jenkins Helm repository..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Deploy Jenkins
echo "🚀 Installing Jenkins with Helm..."
helm upgrade --install jenkins jenkins/jenkins \
    --namespace jenkins \
    --values jenkins/values.yaml \
    --wait \
    --timeout 10m

# Apply ingress
echo "🌐 Creating Jenkins ingress..."
kubectl apply -f jenkins/ingress.yaml

echo "⏳ Waiting for Jenkins to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jenkins -n jenkins --timeout=600s

# Give Jenkins time to process init scripts
echo "⏳ Waiting for init scripts to complete..."
sleep 45

echo "✅ Jenkins deployed successfully!"
echo "📝 Access info:"
echo "   URL: http://jenkins.localhost"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🤖 The 'time-recorder' job should be automatically created!"
echo "   It will run every 5 minutes to record timestamps to PostgreSQL"
echo ""
echo "🔍 To verify the job was created:"
echo "   1. Go to http://jenkins.localhost"
echo "   2. Look for 'time-recorder' job"
echo "   3. Or check: kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins | grep 'time-recorder'"