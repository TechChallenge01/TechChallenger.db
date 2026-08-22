output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do EKS"
  value       = aws_eks_cluster.cluster.endpoint
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR (para referencia; a esteira descobre isso sozinha)"
  value       = aws_ecr_repository.app.repository_url
}

output "database_endpoint" {
  description = "Endpoint de conexao do RDS SQL Server"
  value       = aws_db_instance.sqlserver.endpoint
}

output "database_username" {
  description = "Usuario master do banco"
  value       = aws_db_instance.sqlserver.username
  sensitive   = true
}
