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