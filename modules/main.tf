resource "aws_key_pair" "olimpo_app_key" {
  public_key = file("./keys/olimpo_app_key.pub")
  key_name   = var.aws_key_pair_name
}

resource "aws_security_group" "olimpo_sg" {
  name        = var.aws_olimpo_sg
  description = "Permitir Conexiones por SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "olimpo_app_server" {
  ami           = "ami-0cfde0ea8edd312d4"
  instance_type = var.aws_instance_type
  key_name      = aws_key_pair.olimpo_app_key.key_name
  user_data     = filebase64("${path.module}/vm/scripts/apps-install.sh")
  vpc_security_group_ids = [
    aws_security_group.olimpo_sg.id
  ]
  tags = {
    Name = "${var.aws_server_name} - ${var.aws_environment}"
  }

  //PROVISIONERS
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./keys/olimpo_app_key")
      host        = self.public_ip
    }
    inline = [
      "echo 'Conexión Exitosa!'"
    ]
  }
}
