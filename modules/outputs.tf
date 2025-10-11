output "aws_instance_ip" {
  value = aws_instance.olimpo_app_server.*.public_ip
}

