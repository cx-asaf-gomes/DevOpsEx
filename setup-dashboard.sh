#!/bin/bash
set -e

echo "🚀 PostgreSQL Performance Dashboard - Complete Setup"
echo "===================================================="
echo ""
echo "This script will:"
echo "✓ Create Terraform configuration files"
echo "✓ Setup PostgreSQL database tables"  
echo "✓ Deploy Grafana dashboard via Terraform"
echo "✓ Provide dashboard access URL"
echo ""

# Configuration variables (updated for your Bitnami setup)
TERRAFORM_DIR="terraform-dashboard"
GRAFANA_URL="http://grafana.localhost"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"
POSTGRES_NAMESPACE="postgres"
POSTGRES_STATEFULSET="postgresql"  # Bitnami uses StatefulSet
POSTGRES_SERVICE="postgresql.postgres.svc.cluster.local"

echo "📋 Prerequisites Check..."

# Check if kubectl is available and cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl not available or cluster not running"
    echo "Please ensure your k3d cluster is running: k3d cluster start"
    exit 1
fi

# Check if Grafana is accessible
echo "Checking Grafana accessibility..."
if ! curl -s -f "$GRAFANA_URL/api/health" &> /dev/null; then
    echo "❌ Grafana not accessible at $GRAFANA_URL"
    echo "Please check if Grafana is running and accessible"
    exit 1
fi

# Check if PostgreSQL StatefulSet is running (Bitnami uses StatefulSet, not Deployment)
echo "Checking PostgreSQL StatefulSet..."
if ! kubectl get statefulset/$POSTGRES_STATEFULSET -n $POSTGRES_NAMESPACE &> /dev/null; then
    echo "❌ PostgreSQL StatefulSet '$POSTGRES_STATEFULSET' not found in namespace '$POSTGRES_NAMESPACE'"
    echo "Current PostgreSQL resources:"
    kubectl get all -n $POSTGRES_NAMESPACE | grep postgresql
    exit 1
fi

# Check if PostgreSQL pod is ready
echo "Checking PostgreSQL pod status..."
POSTGRES_POD=$(kubectl get pods -n $POSTGRES_NAMESPACE -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POSTGRES_POD" ]; then
    echo "❌ No PostgreSQL pods found"
    exit 1
fi

echo "✅ Found PostgreSQL pod: $POSTGRES_POD"
echo "✅ All prerequisites satisfied!"
echo ""

# Create terraform directory
echo "📁 Creating Terraform project directory..."
rm -rf $TERRAFORM_DIR
mkdir -p $TERRAFORM_DIR
cd $TERRAFORM_DIR

echo "📝 Creating Terraform configuration files..."

# Create main.tf with your exact PostgreSQL service details
cat > main.tf << 'TERRAFORM_MAIN_EOF'
terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = "${var.grafana_username}:${var.grafana_password}"
}

resource "grafana_data_source" "postgresql" {
  type = "postgres"
  name = "PostgreSQL"
  url  = var.postgresql_url

  database_name = var.postgresql_database
  username      = var.postgresql_username

  secure_json_data_encoded = jsonencode({
    password = var.postgresql_password
  })

  json_data_encoded = jsonencode({
    sslmode         = "disable"
    maxOpenConns    = 100
    maxIdleConns    = 100
    connMaxLifetime = 14400
  })
}

resource "grafana_dashboard" "postgresql_performance" {
  config_json = jsonencode({
    title       = "PostgreSQL Performance Dashboard"
    description = "Comprehensive PostgreSQL performance metrics: CPU, Memory, Throughput, and Jenkins Integration"
    tags        = ["postgresql", "performance", "jenkins", "k3d", "bitnami"]
    timezone    = "browser"
    refresh     = "10s"
    time = {
      from = "now-30m"
      to   = "now"
    }
    editable = true
    panels = [
      {
        id    = 1
        title = "Jenkins Job Activity"
        type  = "timeseries"
        gridPos = {
          h = 6
          w = 8
          x = 0
          y = 0
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT date_trunc('minute', timestamp) AS time, COUNT(*) AS \"Log Entries per Minute\" FROM logs WHERE timestamp >= NOW() - INTERVAL '30 minutes' GROUP BY date_trunc('minute', timestamp) ORDER BY time;"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              drawStyle         = "line"
              lineInterpolation = "smooth"
              lineWidth         = 3
              fillOpacity       = 30
              showPoints        = "always"
              pointSize         = 6
            }
          }
        }
      },
      {
        id    = 2
        title = "CPU Usage - Active Backends"
        type  = "timeseries"
        gridPos = {
          h = 6
          w = 8
          x = 8
          y = 0
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() AS time, numbackends AS \"Active Backends\", (xact_commit + xact_rollback) AS \"Total Transactions\" FROM pg_stat_database WHERE datname = 'postgres';"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              drawStyle         = "line"
              lineInterpolation = "smooth"
              lineWidth         = 3
              fillOpacity       = 30
              showPoints        = "always"
              pointSize         = 6
            }
          }
        }
      },
      {
        id    = 3
        title = "Memory Usage - Database Size"
        type  = "timeseries"
        gridPos = {
          h = 6
          w = 8
          x = 16
          y = 0
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() AS time, ROUND(pg_database_size('postgres') / 1024.0 / 1024.0, 2) AS \"Database Size (MB)\", SUM(blks_hit + blks_read) AS \"Buffer Access\" FROM pg_stat_database WHERE datname = 'postgres' GROUP BY pg_database_size('postgres');"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              drawStyle         = "line"
              lineInterpolation = "smooth"
              lineWidth         = 3
              fillOpacity       = 30
              showPoints        = "always"
              pointSize         = 6
            }
          }
        }
      },
      {
        id    = 4
        title = "Transaction Throughput"
        type  = "timeseries"
        gridPos = {
          h = 6
          w = 12
          x = 0
          y = 6
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() AS time, xact_commit AS \"Committed Transactions\", xact_rollback AS \"Rolled Back Transactions\", tup_inserted AS \"Rows Inserted\", tup_updated AS \"Rows Updated\" FROM pg_stat_database WHERE datname = 'postgres';"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              drawStyle         = "line"
              lineInterpolation = "smooth"
              lineWidth         = 3
              fillOpacity       = 30
              showPoints        = "always"
              pointSize         = 6
            }
          }
        }
      },
      {
        id    = 5
        title = "Active Connections"
        type  = "timeseries"
        gridPos = {
          h = 6
          w = 12
          x = 12
          y = 6
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() AS time, COUNT(CASE WHEN state = 'active' THEN 1 END) AS \"Active Connections\", COUNT(CASE WHEN state = 'idle' THEN 1 END) AS \"Idle Connections\", COUNT(*) AS \"Total Connections\" FROM pg_stat_activity WHERE datname = 'postgres' OR datname IS NULL;"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              drawStyle         = "line"
              lineInterpolation = "smooth"
              lineWidth         = 3
              fillOpacity       = 30
              showPoints        = "always"
              pointSize         = 6
            }
          }
        }
      },
      {
        id    = 6
        title = "Cache Hit Ratio"
        type  = "gauge"
        gridPos = {
          h = 6
          w = 8
          x = 0
          y = 12
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() as time, ROUND((SUM(blks_hit) * 100.0) / NULLIF(SUM(blks_hit + blks_read), 0), 2) as \"Cache Hit Ratio\" FROM pg_stat_database WHERE datname = 'postgres';"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "red"
                  value = null
                },
                {
                  color = "yellow"
                  value = 80
                },
                {
                  color = "green"
                  value = 95
                }
              ]
            }
            max  = 100
            min  = 0
            unit = "percent"
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs  = ["lastNotNull"]
            fields = ""
          }
          orientation            = "auto"
          showThresholdLabels    = false
          showThresholdMarkers   = true
        }
      },
      {
        id    = 7
        title = "Jenkins Job Status"
        type  = "stat"
        gridPos = {
          h = 6
          w = 8
          x = 8
          y = 12
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() as time, COUNT(*) as \"Total Logs\", COALESCE(EXTRACT(EPOCH FROM (NOW() - MAX(timestamp))) / 60, 0) as \"Minutes Since Last\" FROM logs;"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                },
                {
                  color = "yellow"
                  value = 6
                },
                {
                  color = "red"
                  value = 10
                }
              ]
            }
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs  = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode    = "auto"
          colorMode   = "value"
          graphMode   = "area"
          justifyMode = "auto"
        }
      },
      {
        id    = 8
        title = "Database Size"
        type  = "stat"
        gridPos = {
          h = 6
          w = 8
          x = 16
          y = 12
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() as time, ROUND(pg_database_size('postgres') / 1024.0 / 1024.0, 2) as \"Database Size (MB)\""
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                },
                {
                  color = "yellow"
                  value = 100
                },
                {
                  color = "red"
                  value = 500
                }
              ]
            }
            unit = "MB"
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs  = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode    = "auto"
          colorMode   = "value"
          graphMode   = "area"
          justifyMode = "auto"
        }
      },
      {
        id    = 9
        title = "Jenkins Job Health Monitor"
        type  = "stat"
        gridPos = {
          h = 4
          w = 8
          x = 0
          y = 18
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT NOW() as time, CASE WHEN COUNT(*) = 0 THEN 0 WHEN EXTRACT(EPOCH FROM (NOW() - MAX(timestamp))) / 60 < 6 THEN 1 WHEN EXTRACT(EPOCH FROM (NOW() - MAX(timestamp))) / 60 < 10 THEN 0.5 ELSE 0 END as \"Job Health Status\" FROM logs;"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "red"
                  value = null
                },
                {
                  color = "yellow"
                  value = 0.5
                },
                {
                  color = "green"
                  value = 1
                }
              ]
            }
            max = 1
            min = 0
          }
          overrides = [
            {
              matcher = {
                id      = "byName"
                options = "Job Health Status"
              }
              properties = [
                {
                  id = "mappings"
                  value = [
                    {
                      options = {
                        "0" = {
                          text = "FAILED"
                        }
                        "0.5" = {
                          text = "WARNING"
                        }
                        "1" = {
                          text = "HEALTHY"
                        }
                      }
                      type = "value"
                    }
                  ]
                }
              ]
            }
          ]
        }
        options = {
          reduceOptions = {
            values = false
            calcs  = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode    = "auto"
          colorMode   = "background"
          graphMode   = "none"
          justifyMode = "center"
        }
      },
      {
        id    = 10
        title = "Recent Log Entries (Last 10)"
        type  = "table"
        gridPos = {
          h = 8
          w = 16
          x = 8
          y = 18
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT id as \"ID\", timestamp as \"Timestamp\", message as \"Message\", level as \"Level\", ROUND(EXTRACT(EPOCH FROM (NOW() - timestamp)) / 60, 1) as \"Minutes Ago\" FROM logs ORDER BY timestamp DESC LIMIT 10;"
            format = "table"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                }
              ]
            }
          }
        }
        options = {
          showHeader = true
          sortBy = [
            {
              displayName = "Timestamp"
              desc        = true
            }
          ]
        }
      },
      {
        id    = 11
        title = "Time Records Activity"
        type  = "timeseries"
        gridPos = {
          h = 6
          w = 12
          x = 0
          y = 26
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT date_trunc('hour', recorded_at) AS time, COUNT(*) AS \"Records per Hour\" FROM time_records WHERE recorded_at >= NOW() - INTERVAL '24 hours' GROUP BY date_trunc('hour', recorded_at) ORDER BY time;"
            format = "time_series"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              drawStyle         = "bars"
              lineInterpolation = "linear"
              lineWidth         = 1
              fillOpacity       = 80
              showPoints        = "never"
              pointSize         = 5
            }
          }
        }
      },
      {
        id    = 12
        title = "Recent Time Records"
        type  = "table"
        gridPos = {
          h = 6
          w = 12
          x = 12
          y = 26
        }
        targets = [
          {
            datasource = {
              type = "postgres"
              uid  = grafana_data_source.postgresql.uid
            }
            rawSql = "SELECT id as \"ID\", recorded_at as \"Recorded At\", pod_name as \"Pod Name\", node_name as \"Node Name\", ROUND(EXTRACT(EPOCH FROM (NOW() - recorded_at)) / 60, 1) as \"Minutes Ago\" FROM time_records ORDER BY recorded_at DESC LIMIT 10;"
            format = "table"
          }
        ]
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            custom = {
              align       = "auto"
              displayMode = "auto"
            }
          }
          overrides = [
            {
              matcher = {
                id      = "byName"
                options = "Recorded At"
              }
              properties = [
                {
                  id    = "custom.width"
                  value = 180
                }
              ]
            }
          ]
        }
        options = {
          showHeader = true
          sortBy = [
            {
              displayName = "Recorded At"
              desc        = true
            }
          ]
        }
      }
    ]
  })
}
TERRAFORM_MAIN_EOF

# Create variables.tf (updated for your PostgreSQL service)
cat > variables.tf << 'TERRAFORM_VARS_EOF'
variable "grafana_url" {
  description = "Grafana server URL"
  type        = string
  default     = "http://grafana.localhost"
}

variable "grafana_username" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "postgresql_url" {
  description = "PostgreSQL connection URL"
  type        = string
  default     = "postgresql.postgres.svc.cluster.local:5432"
}

variable "postgresql_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "postgres"
}

variable "postgresql_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "admin"
}

variable "postgresql_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "admin123"
  sensitive   = true
}
TERRAFORM_VARS_EOF

# Create terraform.tfvars (updated for your exact setup)
cat > terraform.tfvars << 'TERRAFORM_TFVARS_EOF'
grafana_url      = "http://grafana.localhost"
grafana_username = "admin"
grafana_password = "admin123"

postgresql_url      = "postgresql.postgres.svc.cluster.local:5432"
postgresql_database = "postgres"
postgresql_username = "admin"
postgresql_password = "admin123"
TERRAFORM_TFVARS_EOF

# Create outputs.tf
cat > outputs.tf << 'TERRAFORM_OUTPUTS_EOF'
output "postgresql_datasource_uid" {
  description = "The UID of the PostgreSQL data source"
  value       = grafana_data_source.postgresql.uid
}

output "postgresql_datasource_id" {
  description = "The ID of the PostgreSQL data source"
  value       = grafana_data_source.postgresql.id
}

output "dashboard_url" {
  description = "URL to access the PostgreSQL Performance Dashboard"
  value       = "${var.grafana_url}/d/${grafana_dashboard.postgresql_performance.uid}"
}

output "dashboard_uid" {
  description = "The UID of the dashboard"
  value       = grafana_dashboard.postgresql_performance.uid
}
TERRAFORM_OUTPUTS_EOF

echo "✅ Terraform configuration files created!"
echo ""

echo "🗄️ Setting up PostgreSQL database tables..."

# Test PostgreSQL connectivity first
echo "Testing PostgreSQL connection..."
if ! kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- psql -U admin -d postgres -c "SELECT 1;" &> /dev/null; then
    echo "❌ Cannot connect to PostgreSQL. Please check your credentials."
    echo "💡 Try running: kubectl exec -n postgres $POSTGRES_POD -- psql -U admin -d postgres"
    exit 1
fi

echo "✅ PostgreSQL connection successful!"

# Create database tables using the correct pod name
echo "📊 Creating tables..."
kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- psql -U admin -d postgres -c "
CREATE TABLE IF NOT EXISTS logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    message TEXT,
    level VARCHAR(50) DEFAULT 'INFO'
);" || echo "⚠️ Logs table creation failed (might already exist)"

kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- psql -U admin -d postgres -c "
CREATE TABLE IF NOT EXISTS time_records (
    id SERIAL PRIMARY KEY,
    recorded_at TIMESTAMP NOT NULL,
    pod_name VARCHAR(255),
    node_name VARCHAR(255)
);" || echo "⚠️ Time records table creation failed (might already exist)"

echo "📈 Inserting sample data..."

# Insert sample data
kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- psql -U admin -d postgres -c "
INSERT INTO logs (timestamp, message, level) VALUES 
    (NOW() - INTERVAL '1 minute', 'Jenkins pipeline started', 'INFO'),
    (NOW() - INTERVAL '2 minutes', 'Database connection established', 'INFO'),
    (NOW() - INTERVAL '3 minutes', 'Job completed successfully', 'INFO'),
    (NOW() - INTERVAL '5 minutes', 'Scheduled task triggered', 'INFO'),
    (NOW() - INTERVAL '8 minutes', 'System health check passed', 'DEBUG'),
    (NOW() - INTERVAL '10 minutes', 'Configuration updated', 'INFO'),
    (NOW() - INTERVAL '12 minutes', 'Performance monitoring active', 'INFO'),
    (NOW() - INTERVAL '15 minutes', 'Dashboard deployment started', 'INFO')
ON CONFLICT DO NOTHING;"

kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- psql -U admin -d postgres -c "
INSERT INTO time_records (recorded_at, pod_name, node_name) VALUES 
    (NOW() - INTERVAL '5 minutes', 'jenkins-agent-pod-1', 'k3d-cluster-server-0'),
    (NOW() - INTERVAL '10 minutes', 'jenkins-agent-pod-2', 'k3d-cluster-agent-0'),
    (NOW() - INTERVAL '15 minutes', 'jenkins-agent-pod-3', 'k3d-cluster-server-0'),
    (NOW() - INTERVAL '20 minutes', 'jenkins-agent-pod-4', 'k3d-cluster-agent-1'),
    (NOW() - INTERVAL '25 minutes', 'jenkins-agent-pod-5', 'k3d-cluster-server-0')
ON CONFLICT DO NOTHING;"

echo "✅ Database setup complete!"

# Verify data
echo "📋 Verifying database setup..."
kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- psql -U admin -d postgres -c "
SELECT 'logs' as table_name, COUNT(*) as record_count FROM logs
UNION ALL
SELECT 'time_records' as table_name, COUNT(*) as record_count FROM time_records;"

echo ""
echo "🏗️ Initializing Terraform..."

# Initialize Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform first:"
    echo "   brew install terraform  # On macOS"
    echo "   sudo apt install terraform  # On Ubuntu"
    exit 1
fi

terraform init

echo ""
echo "📋 Planning Terraform deployment..."
terraform plan

echo ""
echo "🚀 Applying Terraform configuration..."
echo "This will create:"
echo "  ✓ PostgreSQL data source in Grafana"
echo "  ✓ Comprehensive dashboard with 12 panels"
echo ""

read -p "Press Enter to continue with deployment (Ctrl+C to cancel)..."

terraform apply -auto-approve

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! Dashboard deployed successfully!"
    echo ""
    echo "📊 DASHBOARD ACCESS INFORMATION:"
    echo "================================"
    echo "🔗 Dashboard URL: $(terraform output -raw dashboard_url)"
    echo "👤 Username: admin"
    echo "🔑 Password: admin123"
    echo ""
    echo "📈 DASHBOARD FEATURES:"
    echo "• Jenkins Job Activity - Real-time log monitoring"
    echo "• CPU Usage - Active database backends"
    echo "• Memory Usage - Database size and buffer access"
    echo "• Transaction Throughput - Commits, rollbacks, inserts"
    echo "• Active Connections - Real-time connection monitoring"
    echo "• Cache Hit Ratio - Memory efficiency gauge"
    echo "• Jenkins Job Status - Job health monitoring"
    echo "• Database Size - Storage utilization"
    echo "• Job Health Monitor - Visual status indicator"
    echo "• Recent Logs & Time Records - Activity tables"
    echo ""
    echo "🔄 The dashboard refreshes every 10 seconds"
    echo "📊 Your Jenkins job will populate data every 5 minutes"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Open the dashboard URL in your browser"
    echo "2. Login with the credentials above"
    echo "3. Verify all panels are displaying data"
    echo "4. Monitor your PostgreSQL performance in real-time!"
    echo ""
    echo "🗂️ Terraform files are saved in: $(pwd)"
    echo ""
    echo "📝 PostgreSQL Connection Details (verified working):"
    echo "   Host: $POSTGRES_SERVICE"
    echo "   Database: postgres"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo "   Pod: $POSTGRES_POD"
else
    echo "❌ Terraform deployment failed!"
    echo "Check the error messages above for troubleshooting."
    exit 1
fi