# modules/outputs.tf

output "ecr_repository_url" {
  description = "La URL del repositorio de ECR para subir imágenes Docker."
  value       = aws_ecr_repository.olimpo_ecr_repo.repository_url
}