# modules/outputs.tf

output "ecr_repository_url" {
  description = "La URL del repositorio de ECR para subir imágenes Docker."
  value       = aws_ecr_repository.olimpo_ecr_repo.repository_url
}

# modules/outputs.tf (añadir al final)

output "alb_dns_name" {
  description = "El nombre DNS público del Application Load Balancer."
  value       = aws_lb.olimpo_alb.dns_name
}