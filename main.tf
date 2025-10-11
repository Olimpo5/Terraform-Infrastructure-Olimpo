# Bloque de configuración principal de Terraform
terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
        }
    }

    # --- Backend Configuration ---
    # Por ahora, usaremos un backend "local", que guarda el archivo de estado
    # en la misma carpeta del proyecto (terraform.tfstate). Es ideal para empezar.
    backend "local" {
        path = "terraform.tfstate"
    }

    # MÁS ADELANTE, podríamos cambiar a un backend remoto como S3 con este código:
    /*
    backend "s3" {
        bucket         = "nombre-de-tu-bucket-tfstate"
        key            = "olimpo/terraform.tfstate"
        region         = "us-east-1"
        encrypt        = true
        dynamodb_table = "terraform-lock-table"
    }
    */
    }

    # Configuración del proveedor de AWS (nuestra "conexión" a la nube)
    provider "aws" {
    region = var.aws_region
    }

    # --- Recurso de Prueba ---
    # Esto es solo para verificar que nuestras variables de entorno funcionan.
    # Creará un archivo de texto en tu computadora llamado 'entorno.txt'
    # con el nombre del entorno que estemos usando (dev, qa, o prod).
    resource "local_file" "environment_check" {
    content  = "Este archivo confirma que estamos desplegando el entorno: ${var.environment}"
    filename = "${path.module}/entorno.txt"
}