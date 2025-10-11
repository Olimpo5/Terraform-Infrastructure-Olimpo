variable "aws_region" {
  description = "La región de AWS donde se crearán los recursos."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "El nombre del entorno (ej: dev, qa, prod)."
  type        = string
}