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
