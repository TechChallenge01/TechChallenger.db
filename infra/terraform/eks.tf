resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    security_group_ids      = [aws_security_group.eks_nodes.id]
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = var.node_instance_types

  tags = {
    Name = "${var.cluster_name}-nodes"
  }
}

# --- A partir daqui: instalação do metrics-server (necessário para o HPA funcionar) ---

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.name
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  # Necessário na maioria dos clusters de laboratório, por causa do certificado do kubelet
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.nodes,
  ]
}
