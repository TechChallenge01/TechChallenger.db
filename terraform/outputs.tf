output "database_endpoint" {
  description = "Endpoint de conexao do RDS SQL Server (host:porta)"
  value       = aws_db_instance.sqlserver.endpoint
}

output "database_username" {
  description = "Usuario master do banco"
  value       = aws_db_instance.sqlserver.username
  sensitive   = true
}
