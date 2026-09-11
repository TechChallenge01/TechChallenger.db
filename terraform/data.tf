# Este repo NAO provisiona rede nem cluster -- eles vem do TechChallenger.k8s.
# Descobrimos os recursos por tag/nome (data source), sem acoplar os states dos
# dois repositorios (nenhum precisa de acesso ao backend do outro).

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = [var.public_subnet_name_pattern]
  }
}

data "aws_eks_cluster" "app" {
  name = var.eks_cluster_name
}
