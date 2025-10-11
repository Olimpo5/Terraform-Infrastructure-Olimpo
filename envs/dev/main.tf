module "vm-linux-server" {
  source            = "../../modules"
  aws_access_key    = var.AWS_ACCESS_KEY
  aws_secret_key    = var.AWS_SECRET_KEY
  aws_key_pair_name = var.AWS_KEY_PAIR_NAME
  aws_region        = var.AWS_REGION
  aws_environment   = var.AWS_ENVIRONMENT
  aws_olimpo_sg     = var.AWS_OLIMPO_SG
  aws_instance_type = var.AWS_INSTANCE_TYPE
  aws_server_name   = var.AWS_SERVER_NAME
}

output "vm-linux-server-ip" {
  value = module.vm-linux-server.aws_instance_ip
}

