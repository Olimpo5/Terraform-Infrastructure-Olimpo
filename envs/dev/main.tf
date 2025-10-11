# envs/dev/main.tf

module "olimpo_infra" {
  source = "../../modules"

  aws_region      = var.AWS_REGION
  aws_environment = var.AWS_ENVIRONMENT
  # La variable "project_name" usará el valor por defecto ("olimpo") que definimos en el módulo
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR."
  value       = module.olimpo_infra.ecr_repository_url
}

# envs/dev/main.tf (añadir al final)

output "alb_dns_name" {
  description = "Nombre DNS público del ALB."
  value       = module.olimpo_infra.alb_dns_name
}