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
    description = "Comprehensive PostgreSQL performance metrics"
    tags        = ["postgresql", "performance", "jenkins", "k3d"]
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
      }
    ]
  })
}