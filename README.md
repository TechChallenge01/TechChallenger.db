# TechChallenge.db

## Descrição
Infraestrutura como código (Terraform) do **banco de dados gerenciado** do Tech Challenge: uma instância RDS SQL Server Express, exclusiva deste repositório. Não cria rede nem cluster — descobre a VPC e o security group do cluster criados pelo [`TechChallenger.k8s`](https://github.com/TechChallenge01/TechChallenger.k8s) via `data source` (por tag/nome), sem acoplar os states dos dois repositórios.

Este repositório é um dos quatro que compõem o Tech Challenge:

| Repositório | Papel |
|---|---|
| [TechChallenge](https://github.com/TechChallenge01/TechChallenge) | Aplicação principal (API em Kubernetes) |
| [TechChallenger.auth](https://github.com/TechChallenge01/TechChallenger.auth) | API Gateway + Function Serverless de autenticação por CPF |
| **TechChallenger.db** (este) | Infraestrutura do banco de dados gerenciado (Terraform) |
| [TechChallenger.k8s](https://github.com/TechChallenge01/TechChallenger.k8s) | Infraestrutura do cluster Kubernetes e rede (Terraform) |

## Tecnologias utilizadas
- **Terraform** >= 1.5 — provider `hashicorp/aws` ~> 5.0
- **AWS RDS for SQL Server** (edição Express) — banco relacional gerenciado
- **AWS Academy Learner Lab** — usa a `LabRole` implícita da conta (nenhum recurso IAM próprio é criado)

## Arquitetura

```mermaid
flowchart TB
    subgraph K8SREPO["VPC (provisionada pelo TechChallenger.k8s)"]
        EKSSG["Security group do cluster EKS<br/>(data source)"]
        subgraph PUB["Subnets públicas (achadas via data source)"]
            RDS[(RDS SQL Server<br/>Express · db.t3.small)]
        end
    end
    SG["security_group.sqlserver<br/>(criado aqui)"]
    SG -->|1433 a partir do| EKSSG
    SG -->|1433 de IP(s) específicos| SSMS[Acesso via SSMS<br/>desenvolvimento]
    RDS --- SG

    APP[TechChallenge API] -->|ConnectionString| RDS
    AUTHLAMBDA[Lambda de autenticação<br/>TechChallenger.auth] -->|leitura, mesma VPC| RDS
```

## O que é provisionado

| Recurso | Arquivo | Descrição |
|---|---|---|
| VPC / subnets / EKS do cluster | `data.tf` | **Não provisiona** — descobre por `data source` o que o `TechChallenger.k8s` já criou (tag `Name` da VPC, subnets públicas, cluster EKS) |
| Subnet group do RDS | `sqlserver.tf` | Usa as subnets públicas descobertas (acesso via SSMS durante o desenvolvimento) |
| Security group do RDS | `sqlserver.tf` | Libera 1433 a partir do security group do cluster EKS (`data.aws_eks_cluster`) e, opcionalmente, de IPs específicos (`var.ssms_allowed_cidrs`) |
| RDS SQL Server (Express, `license-included`) | `sqlserver.tf` | Usuário master `dbadmin` (`sa` é reservado) |
| Variáveis / outputs / provider | `variables.tf`, `outputs.tf`, `provider.tf` | Parametrização e valores expostos após o apply |

## Pré-requisitos

- **Terraform** >= 1.5 e **AWS CLI v2**
- Credenciais temporárias do **AWS Academy Learner Lab** em `~/.aws/credentials`
- Região `us-east-1`
- **O [`TechChallenger.k8s`](https://github.com/TechChallenge01/TechChallenger.k8s) já aplicado** — este repo depende da VPC e do cluster EKS dele (descobertos por tag/nome, não por remote state)

## Como aplicar

```powershell
cd terraform

# Senha do RDS (8-128 chars):
$env:TF_VAR_db_password = "TrocarEssaSenha@2026"

terraform init -backend-config="bucket=<BUCKET_DO_STATE>"
terraform plan -out tfplan
terraform apply "tfplan"       # ~8-10 min
terraform output
```

Outputs relevantes: `database_endpoint` (host:porta), `database_username`. Esses valores alimentam o Secret do Kubernetes da API principal (`RDS_CONNECTION_STRING`) e o `terraform.tfvars`/secret `RDS_CONNECTION_STRING` do `TechChallenger.auth`.

## Como destruir

```powershell
cd terraform
terraform init -backend-config="bucket=<BUCKET_DO_STATE>"
$env:TF_VAR_db_password = "<a mesma senha usada no apply>"
terraform destroy
```

> **Ordem:** destrua primeiro o stack do [`TechChallenger.auth`](https://github.com/TechChallenge01/TechChallenger.auth) (ele referencia o security group deste RDS) e só depois este. O `TechChallenger.k8s` deve ser destruído por último (este repo depende da VPC/EKS dele). O RDS não gera snapshot final (`skip_final_snapshot = true`).

## Estado do Terraform

Backend **S3** (bucket compartilhado com os demais repos do Tech Challenge, key `techchallenge-db/terraform.tfstate`, versionamento ligado). O bucket é passado em tempo de `init` (`-backend-config="bucket=..."`), nunca fixo no código.

## CI/CD

- **`ci.yml`** — em todo PR para `main`: `terraform fmt` (advisório) + `terraform validate` (`-backend=false`, não precisa de credenciais AWS nem de senha do banco).
- **`cd.yml`** — em todo push na `main` (só entra via PR, branch protegida) ou disparo manual: autentica com as credenciais temporárias do Learner Lab e roda `terraform apply`. Pressupõe o `TechChallenger.k8s` já aplicado (VPC/EKS descobertos via data source). Único ambiente, mesmo racional do `TechChallenger.k8s`.

Secrets necessários no repositório: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (temporários do Learner Lab), `TF_STATE_BUCKET` (bucket do state) e `DB_PASSWORD` (senha master do RDS — sem default, obrigatória para o `apply` não travar esperando input).

## Notas

- **Acesso via SSMS:** `var.ssms_allowed_cidrs` libera IP(s) específicos no security group do RDS para depuração manual. Se seu IP público mudar, atualize a variável. Para fechar esse acesso, use `-var 'ssms_allowed_cidrs=[]'`.
- **Segurança:** o RDS está com `publicly_accessible = true` para permitir esse acesso via SSMS durante o desenvolvimento — restrito pelo security group. Para produção, trocar para `publicly_accessible = false`, apontar `db_subnet_group_name` para as subnets privadas do `TechChallenger.k8s` e zerar `ssms_allowed_cidrs`.
- Repositório de infraestrutura: não expõe API, portanto sem Swagger/Postman. Ver os READMEs de [`TechChallenge`](https://github.com/TechChallenge01/TechChallenge) e [`TechChallenger.auth`](https://github.com/TechChallenge01/TechChallenger.auth).
- Documentação arquitetural completa (diagrama de componentes, sequência, modelo ER + justificativa do banco, RFCs, ADRs — inclusive o [ADR sobre ambiente único de infraestrutura](https://github.com/TechChallenge01/TechChallenge/blob/main/docs/architecture/adrs/ADR-005-ambiente-unico-homolog-prod.md)) em [`docs/architecture/`](https://github.com/TechChallenge01/TechChallenge/tree/main/docs/architecture), no repositório `TechChallenge`.
