# Repositório ECR onde a esteira (cd.yml) faz o push da imagem Docker.
# Nao precisa de nenhuma IAM Policy nova: o LabRole ja tem permissao de ECR,
# e as credenciais temporarias do Academy usadas no GitHub Actions herdam essa permissao.
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Permite "terraform destroy" mesmo com imagens dentro do repositorio.
  # Util no Academy, onde o lab e recriado do zero com frequencia.
  force_delete = true

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# Remove imagens antigas automaticamente, para nao acumular custo de armazenamento
# (nao é problema de billing no Academy, mas evita repositorio poluido no trabalho).
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as 10 imagens mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
