# variables.tf

variable "aws_region" {
  description = "La región de AWS para desplegar la infraestructura."
  type        = string
  default     = "us-east-2"
}

variable "aws_environment" {
  description = "El nombre del entorno (ej: dev, qa, prod)."
  type        = string
  default     = "dev"
}

