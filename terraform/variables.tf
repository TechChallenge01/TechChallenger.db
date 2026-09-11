variable "aws_region" {
  description = "Regiao AWS onde a infra sera criada"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo/tag dos recursos"
  type        = string
  default     = "techchallenge"
}

variable "vpc_name" {
  description = "Tag Name da VPC criada pelo repo TechChallenger.k8s"
  type        = string
  default     = "techchallenge-vpc"
}

variable "public_subnet_name_pattern" {
  description = "Padrao (com wildcard) da tag Name das subnets publicas do TechChallenger.k8s, onde o RDS e colocado hoje (acesso via SSMS)"
  type        = string
  default     = "techchallenge-public-*"
}

variable "eks_cluster_name" {
  description = "Nome do cluster EKS criado pelo repo TechChallenger.k8s (usado para liberar acesso do EKS ao banco)"
  type        = string
  default     = "techchallenge"
}

variable "db_username" {
  description = "Usuario master do RDS. NAO pode ser 'sa', 'admin' ou outra palavra reservada do SQL Server"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Senha master do RDS. Defina via TF_VAR_db_password ou -var, nunca em texto plano no repositorio"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128
    error_message = "A senha do SQL Server deve ter entre 8 e 128 caracteres."
  }
}

variable "db_instance_class" {
  description = "Classe da instancia do RDS"
  type        = string
  default     = "db.t3.small"
}

variable "db_engine_version" {
  description = "Versao do engine SQL Server Express"
  type        = string
  default     = "15.00"
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado (GB) para o RDS"
  type        = number
  default     = 20
}

variable "ssms_allowed_cidrs" {
  description = "IPs (CIDR) liberados no security group do RDS para acesso via SSMS durante o desenvolvimento. Lista vazia = sem acesso externo (fica so o acesso vindo do EKS)."
  type        = list(string)
  default     = ["179.111.170.52/32"]
}
