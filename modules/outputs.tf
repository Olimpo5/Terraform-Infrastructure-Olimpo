# OUTPUTS
# En este output mostramos la ip publica del servidor ec2
output "olimpo_server_public_ip_output" {
  value = aws_instance.olimpo_server.public_ip
}

# En este output mostramos la ip privada del servidor ec2
output "olimpo_server_private_ip_output" {
  value = aws_instance.olimpo_server.private_ip
}
