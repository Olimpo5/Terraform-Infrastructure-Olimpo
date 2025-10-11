provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}

terraform {
  backend "s3" {
    bucket         = var.AWS_NAME_BUCKET
    key            = "terraform.tfstate"
    region         = var.AWS_REGION
    encrypt        = true
    dynamodb_table = "olimpo-terraform-state-lock"
  }
}
