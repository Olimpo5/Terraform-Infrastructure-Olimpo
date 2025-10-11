output "environment_check_content" {
    description = "Muestra el contenido del archivo de prueba para verificar el entorno."
    value       = local_file.environment_check.content
}