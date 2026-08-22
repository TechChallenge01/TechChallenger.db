data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Subnets publicas: onde ficam os nodes do EKS.
# Publicas para evitar o custo de NAT Gateway (~US$32/mes cada) em um projeto academico.
# Em producao real, o ideal e colocar os nodes em subnets privadas atras de um NAT.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${count.index}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Subnets privadas: onde fica o RDS. Sem rota para a internet, so acessivel de dentro da VPC.
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# RDS SQL Server exige no minimo 2 subnets em AZs diferentes, mesmo com uma so instancia
resource "aws_db_subnet_group" "sqlserver" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Subnet group separado (nao edita o de cima) para permitir acesso externo temporario via SSMS.
# O RDS nao deixa remover uma subnet "em uso" de um subnet group existente, entao a forma
# correta de mover a instancia de rede e apontar para um subnet group NOVO, e nao editar
# o subnet_ids do subnet group atual.
# ATENCAO: quando terminar de usar o SSMS, volte sqlserver.tf para usar
# aws_db_subnet_group.sqlserver (privado) em vez deste.
resource "aws_db_subnet_group" "sqlserver_public" {
  name       = "${var.project_name}-db-subnet-group-public"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group-public"
  }
}

# Security group dos nodes do EKS
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-nodes-sg"
  }
}

# Security group do RDS: so aceita conexao SQL Server (1433) vinda dos nodes do EKS
resource "aws_security_group" "sqlserver" {
  name_prefix = "${var.project_name}-sqlserver-"
  vpc_id      = aws_vpc.main.id

  # ATENCAO: aws_security_group.eks_nodes so fica anexado as ENIs do control plane
  # (vpc_config.security_group_ids em eks.tf), NAO aos nos EC2 do node group — o
  # aws_eks_node_group.nodes nao usa launch_template, entao a AWS anexa aos nos o
  # security group "cluster" que ela mesma cria (cluster_security_group_id).
  # Por isso a origem correta aqui e o cluster_security_group_id, nao o eks_nodes.
  ingress {
    description     = "SQL Server access from EKS nodes"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  # ATENCAO: regra temporaria para acesso via SSMS. Remova quando terminar de debugar.
  # Se seu IP publico mudar (rede residencial costuma ser dinamico), atualize aqui.
  ingress {
    description = "Acesso temporario via SSMS"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["179.111.170.52/32"]
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
