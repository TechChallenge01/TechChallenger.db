# RDS SQL Server exige no minimo 2 subnets em AZs diferentes, mesmo com uma so
# instancia. Usa as subnets PUBLICAS da VPC do TechChallenger.k8s (acesso via
# SSMS durante o desenvolvimento) -- ver var.ssms_allowed_cidrs.
resource "aws_db_subnet_group" "sqlserver_public" {
  name       = "${var.project_name}-db-subnet-group-public"
  subnet_ids = data.aws_subnets.public.ids

  tags = {
    Name = "${var.project_name}-db-subnet-group-public"
  }
}

# Security group do RDS: aceita SQL Server (1433) vindo dos nodes do EKS
# (repo TechChallenger.k8s, descoberto via data source) e, opcionalmente,
# de IPs especificos para acesso via SSMS.
resource "aws_security_group" "sqlserver" {
  name_prefix = "${var.project_name}-sqlserver-"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "SQL Server access from EKS nodes"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.app.vpc_config[0].cluster_security_group_id]
  }

  dynamic "ingress" {
    for_each = var.ssms_allowed_cidrs
    content {
      description = "Acesso temporario via SSMS"
      from_port   = 1433
      to_port     = 1433
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sqlserver-sg"
  }
}

resource "aws_db_instance" "sqlserver" {
  identifier     = "${var.project_name}-sqlserver"
  engine         = "sqlserver-ex"
  engine_version = var.db_engine_version
  license_model  = "license-included"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  # "sa" nao pode ser usado: e uma conta reservada do proprio SQL Server e a AWS
  # nem permite escolher esse nome como usuario master (o RDS cria/gerencia a
  # "sa" internamente, desabilitada por padrao).
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.sqlserver_public.name
  vpc_security_group_ids = [aws_security_group.sqlserver.id]

  # true = acesso via internet liberado, restrito pelo security group aos IPs
  # em var.ssms_allowed_cidrs. Para producao: publicly_accessible = false,
  # subnet group privado (subnets privadas do TechChallenger.k8s) e
  # ssms_allowed_cidrs = [].
  publicly_accessible = true

  multi_az                = false # SQL Server Express nao suporta Multi-AZ
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false # troque para true fora de ambiente academico

  tags = {
    Name = "${var.project_name}-sqlserver"
  }
}
