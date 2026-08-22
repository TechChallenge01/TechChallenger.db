# AWS Academy Learner Lab bloqueia iam:CreateRole / iam:AttachRolePolicy.
# Por isso nao criamos roles aqui: usamos a "LabRole" que o proprio Learner Lab
# ja disponibiliza pronta (com as policies necessarias para EKS, EC2, RDS etc.)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
