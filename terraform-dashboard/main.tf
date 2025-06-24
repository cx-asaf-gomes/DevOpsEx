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
