#!/bin/bash
set -e

echo "📊 Setting up PostgreSQL Performance Dashboard..."

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n grafana --timeout=300s

GRAFANA_URL="http://grafana.localhost"
USERNAME="admin"
PASSWORD="admin123"

echo "📊 Creating PostgreSQL Performance Dashboard..."

# Create Simple PostgreSQL Performance Dashboard
curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
  --user "$USERNAME:$PASSWORD" \
  --header "Content-Type: application/json" \
  --data '{
  "dashboard": {
    "id": null,
    "title": "PostgreSQL Performance Metrics",
    "description": "Essential PostgreSQL CPU, Memory, and Throughput monitoring",
    "tags": ["postgresql", "performance"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "CPU - Active Database Connections",
        "description": "Shows how many connections are actively using the database. High numbers indicate CPU load.",
        "type": "timeseries",
        "gridPos": {
          "h": 8,
          "w": 8,
          "x": 0,
          "y": 0
        },
        "targets": [
          {
            "datasource": {
              "type": "postgres",
              "uid": "${datasource}"
            },
            "rawSql": "SELECT NOW() as time, COUNT(*) as \"Active Connections\" FROM pg_stat_activity WHERE state = '\''active'\'';",
            "format": "time_series"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "drawStyle": "line",
              "lineWidth": 3,
              "fillOpacity": 20
            },
            "unit": "short"
          }
        }
      },
      {
        "id": 2,
        "title": "Memory - Cache Hit Ratio",
        "description": "Percentage of data found in memory vs disk. Should be >95%. Lower means more disk I/O (slower).",
        "type": "gauge",
        "gridPos": {
          "h": 8,
          "w": 8,
          "x": 8,
          "y": 0
        },
        "targets": [
          {
            "datasource": {
              "type": "postgres",
              "uid": "${datasource}"
            },
            "rawSql": "SELECT NOW() as time, ROUND((SUM(blks_hit) * 100.0) / NULLIF(SUM(blks_hit + blks_read), 0), 2) as \"Cache Hit %\" FROM pg_stat_database WHERE datname = '\''postgres'\'';",
            "format": "time_series"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "red",
                  "value": 0
                },
                {
                  "color": "yellow", 
                  "value": 90
                },
                {
                  "color": "green",
                  "value": 95
                }
              ]
            },
            "max": 100,
            "min": 0,
            "unit": "percent"
          }
        }
      },
      {
        "id": 3,
        "title": "Throughput - Transactions per Minute",
        "description": "Database transaction rate. Higher = more database activity. Rollbacks indicate failed operations.",
        "type": "timeseries",
        "gridPos": {
          "h": 8,
          "w": 8,
          "x": 16,
          "y": 0
        },
        "targets": [
          {
            "datasource": {
              "type": "postgres",
              "uid": "${datasource}"
            },
            "rawSql": "SELECT NOW() as time, xact_commit as \"Successful Transactions\", xact_rollback as \"Failed Transactions\" FROM pg_stat_database WHERE datname = '\''postgres'\'';",
            "format": "time_series"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "drawStyle": "line",
              "lineWidth": 2,
              "fillOpacity": 10
            }
          }
        }
      },
      {
        "id": 4,
        "title": "Jenkins Jobs & Pod Creation Activity",
        "description": "Shows when Jenkins jobs run and create Kubernetes pods. Each row = one job execution.",
        "type": "table",
        "gridPos": {
          "h": 12,
          "w": 24,
          "x": 0,
          "y": 8
        },
        "targets": [
          {
            "datasource": {
              "type": "postgres",
              "uid": "${datasource}"
            },
            "rawSql": "SELECT id as \"Job ID\", recorded_at as \"Job Execution Time\", pod_name as \"Kubernetes Pod Name\", node_name as \"Cluster Node\", EXTRACT(EPOCH FROM (NOW() - recorded_at))/60 as \"Minutes Ago\" FROM time_records ORDER BY recorded_at DESC LIMIT 20;",
            "format": "table"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "custom": {
              "align": "auto",
              "displayMode": "auto"
            }
          },
          "overrides": [
            {
              "matcher": {
                "id": "byName",
                "options": "Job Execution Time"
              },
              "properties": [
                {
                  "id": "custom.width",
                  "value": 200
                }
              ]
            },
            {
              "matcher": {
                "id": "byName", 
                "options": "Minutes Ago"
              },
              "properties": [
                {
                  "id": "unit",
                  "value": "m"
                },
                {
                  "id": "custom.width",
                  "value": 120
                }
              ]
            }
          ]
        }
      }
    ],
    "uid": "postgres-simple"
  },
  "folderId": 0,
  "overwrite": true
}'

if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL Performance Dashboard created successfully!"
    echo "🔗 View at: $GRAFANA_URL/d/postgres-simple/postgresql-performance-metrics"
else
    echo "⚠️ Dashboard might already exist"
fi

echo ""
echo "🎯 Dashboard created with 4 key panels:"
echo ""
echo "📊 CPU METRICS:"
echo "   • Active Connections - Shows database CPU load"
echo "   • Higher numbers = more work being done"
echo ""
echo "🧠 MEMORY METRICS:" 
echo "   • Cache Hit Ratio - % of data served from memory"
echo "   • Good: >95% | Warning: 90-95% | Poor: <90%"
echo ""
echo "⚡ THROUGHPUT METRICS:"
echo "   • Transactions per minute - Database activity rate"
echo "   • Successful vs Failed transactions"
echo ""
echo "🤖 JOB TRACKING:"
echo "   • Jenkins job executions with timestamps"
echo "   • Kubernetes pod names and nodes"
echo "   • Real-time activity monitoring"