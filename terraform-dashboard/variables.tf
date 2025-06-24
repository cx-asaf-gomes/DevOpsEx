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
