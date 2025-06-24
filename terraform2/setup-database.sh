#!/bin/bash
set -e

echo "🗄️ Setting up PostgreSQL database tables for Grafana dashboard..."

echo "📊 Creating required database tables..."

# Create logs table
kubectl exec -n postgres deployment/postgresql -- psql -U admin -d postgres -c "
CREATE TABLE IF NOT EXISTS logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    message TEXT,
    level VARCHAR(50) DEFAULT 'INFO'
);"

# Create time_records table  
kubectl exec -n postgres deployment/postgresql -- psql -U admin -d postgres -c "
CREATE TABLE IF NOT EXISTS time_records (
    id SERIAL PRIMARY KEY,
    recorded_at TIMESTAMP NOT NULL,
    pod_name VARCHAR(255),
    node_name VARCHAR(255)
);"

echo "📈 Inserting sample data..."

# Insert sample log data
kubectl exec -n postgres deployment/postgresql -- psql -U admin -d postgres -c "
INSERT INTO logs (timestamp, message, level) VALUES 
    (NOW() - INTERVAL '1 minute', 'Jenkins pipeline started', 'INFO'),
    (NOW() - INTERVAL '2 minutes', 'Database connection established', 'INFO'),
    (NOW() - INTERVAL '3 minutes', 'Job completed successfully', 'INFO'),
    (NOW() - INTERVAL '5 minutes', 'Scheduled task triggered', 'INFO'),
    (NOW() - INTERVAL '8 minutes', 'System health check passed', 'DEBUG'),
    (NOW() - INTERVAL '10 minutes', 'Configuration updated', 'INFO')
ON CONFLICT DO NOTHING;"

# Insert sample time records
kubectl exec -n postgres deployment/postgresql -- psql -U admin -d postgres -c "
INSERT INTO time_records (recorded_at, pod_name, node_name) VALUES 
    (NOW() - INTERVAL '5 minutes', 'jenkins-agent-pod-1', 'k3d-cluster-server-0'),
    (NOW() - INTERVAL '10 minutes', 'jenkins-agent-pod-2', 'k3d-cluster-agent-0'),
    (NOW() - INTERVAL '15 minutes', 'jenkins-agent-pod-3', 'k3d-cluster-server-0')
ON CONFLICT DO NOTHING;"

echo "✅ Database setup complete!"

# Verify tables and data
echo "📋 Verifying setup..."
kubectl exec -n postgres deployment/postgresql -- psql -U admin -d postgres -c "
SELECT 'logs' as table_name, COUNT(*) as record_count FROM logs
UNION ALL
SELECT 'time_records' as table_name, COUNT(*) as record_count FROM time_records;"

echo ""
echo "🎯 Database is ready for Terraform deployment!"