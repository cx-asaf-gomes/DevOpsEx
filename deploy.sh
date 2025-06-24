#!/bin/bash
set -e

export CLUSTER_NAME="devops-cluster"
export KUBECONFIG=$(k3d kubeconfig write $CLUSTER_NAME 2>/dev/null || echo "")

ACTION=$1

if [[ "$ACTION" != "install" && "$ACTION" != "uninstall" ]]; then
    echo "Usage: $0 <install|uninstall>"
    exit 1
fi

if [ "$ACTION" == "install" ]; then
    echo "🚀 Starting installation of DevOps cluster..."
    
    # Create the k3d cluster
    ./cluster/environment.sh
    
    # Deploy services
    ./postgres/deploy.sh
    ./jenkins/deploy.sh
    ./grafana/deploy.sh
    
    # Setup Grafana dashboard (Jenkins job is created automatically via JCasC)
    echo ""
    echo "📊 Setting up Grafana dashboard automatically..."
    ./terraform/apply-dashboard.sh
    # ./setup-dashboard.sh
    
    # Check if Jenkins job was created automatically
    echo ""
    echo "🔍 Checking if Jenkins job was created automatically..."
    sleep 10
    
    if curl -s -u admin:admin123 "http://jenkins.localhost/job/time-recorder/" | grep -q "time-recorder"; then
        echo "✅ Jenkins 'time-recorder' job created automatically via JCasC!"
    else
        echo "⚠️ Jenkins job not detected - creating manually..."
        ./jenkins/create-time-recorder-job.sh
    fi
    
    echo ""
    echo "🎉 Installation complete! All services are running."
    echo ""
    echo "📄 Access your services:"
    echo "   Jenkins:           http://jenkins.localhost"
    echo "   Grafana:           http://grafana.localhost"
    echo "   Traefik:           http://traefik.localhost"
    echo ""
    echo "🔐 Credentials:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo "📝 Note: Traefik is handling ingress routing for all services."
    echo ""
    echo "🤖 Jenkins job 'time-recorder' runs every 5 minutes"
    echo "📊 Grafana dashboard: http://grafana.localhost/d/time-records/jenkins-time-records"
    echo ""
    echo "🔍 Verify everything is working:"
    echo "   make status"
    echo "   make test-db"
    echo "   curl -u admin:admin123 http://jenkins.localhost/job/time-recorder/"
    echo ""
else
    echo "🗑️ Starting uninstallation..."
    
    echo "📦 Removing Helm releases..."
    helm uninstall grafana -n grafana 2>/dev/null || true
    helm uninstall jenkins -n jenkins 2>/dev/null || true
    helm uninstall postgresql -n postgres 2>/dev/null || true
    
    echo "🏷️ Removing namespaces..."
    kubectl delete namespace postgres --ignore-not-found=true
    kubectl delete namespace jenkins --ignore-not-found=true
    kubectl delete namespace grafana --ignore-not-found=true
    
    echo "🧨 Deleting K3d cluster..."
    k3d cluster delete $CLUSTER_NAME
    
    echo "✅ Cluster deleted."
fi