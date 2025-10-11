# envs/dev/providers.tf (CORREGIDO)

provider "aws" {
  region = var.AWS_REGION
}

terraform {
  backend "s3" {
    # --- VALORES HARDCODEADOS ---
    # No se pueden usar variables en este bloque.
    bucket         = "olimpo-ablyk" # Escribe el nombre exacto de tu bucket S3 aquí
    key            = "dev/terraform.tfstate" # Es buena práctica separar los estados por entorno
    region         = "us-east-2"    # Escribe la región exacta de tu bucket aquí
    encrypt        = true
    dynamodb_table = "olimpo-terraform-state-lock"
  }
}