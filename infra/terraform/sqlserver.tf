resource "aws_db_instance" "sqlserver" {
  identifier     = "${var.project_name}-sqlserver"
  engine         = "sqlserver-ex"
  engine_version = var.db_engine_version
  license_model  = "license-included"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  # "sa" nao pode ser usado: e uma conta reservada do proprio SQL Server e a AWS
  # nem permite escolher esse nome como usuario master (o RDS cria/gerencia a "sa" internamente,
  # desabilitada por padrao).
  username = var.db_username
  password = var.db_password

  # ATENCAO: apontando para o subnet group PUBLICO temporario (acesso via SSMS).
  # Volte para aws_db_subnet_group.sqlserver quando terminar de debugar.
  db_subnet_group_name   = aws_db_subnet_group.sqlserver_public.name
  vpc_security_group_ids = [aws_security_group.sqlserver.id]

  # ATENCAO: true = acesso via internet liberado, restrito pelo security group
  # ao(s) IP(s) configurados em aws_security_group.sqlserver (vpc.tf).
  # Volte para false quando terminar de usar o SSMS.
  publicly_accessible = true

  multi_az                = false # SQL Server Express nao suporta Multi-AZ
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false # troque para true fora de ambiente academico

  tags = {
    Name = "${var.project_name}-sqlserver"
  }
}
