#CREACION DE UN PAR DE CLAVES
resource "aws_key_pair" "olimpo_app_key" {
  public_key = file("./keys/olimpo_app_key.pub")
  key_name   = var.aws_key_pair_name
}

# CREACION DE UN SECURITY GROUP
resource "aws_security_group" "olimpo_sg" {
  name        = var.aws_olimpo_sg
  description = "Permitir las conexiones por SSH"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Olimpo API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
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

# CREACION DE UN EC2
resource "aws_instance" "olimpo_server" {
  ami           = "ami-0cfde0ea8edd312d4"
  instance_type = var.aws_instance_type
  key_name      = aws_key_pair.olimpo_app_key.key_name

  # Agregamos el script de instalación pero esperamos a que termine
  user_data = filebase64("${path.module}/vm/scripts/apps-install.sh")

  # Importante para que user_data se ejecute completamente antes de provisioners
  user_data_replace_on_change = true

  vpc_security_group_ids = [
    aws_security_group.olimpo_sg.id
  ]

  tags = {
    Name = "${var.aws_server_name} - ${var.aws_environment}"
  }

  # 🔧 MEJORA: Agregamos timeout a la conexión
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./keys/olimpo_app_key")
      host        = self.public_ip
      timeout     = "5m"
    }

    inline = [
      # Esperamos a que cloud-init termine (user_data)
      "echo 'Esperando a que cloud-init termine...'",
      "cloud-init status --wait",

      # Crear directorios
      "sudo mkdir -p /containers",
      "sudo mkdir -p /volumes/nginx/certs",
      "sudo mkdir -p /volumes/nginx/vhostd",
      "sudo mkdir -p /volumes/nginx/html",
      "sudo chmod 777 /volumes/nginx/certs",
      "sudo chmod 777 /volumes/nginx/vhostd",
      "sudo chmod 777 /volumes/nginx/html",
      "mkdir -p /home/ubuntu/.aws",

      # Crear archivo .env
      "sudo touch /containers/.env",
      "sudo chmod 777 /containers",
      "sudo chmod 777 /containers/.env",

      # Variables de entorno
      "sudo echo \"MAIN_DOMAIN=${var.main_domain}\" >> /containers/.env",
      "sudo echo \"POSTGRES_USER=${var.postgres_user}\" >> /containers/.env",
      "sudo echo \"POSTGRES_PASSWORD=${var.postgres_password}\" >> /containers/.env",
      "sudo echo \"POSTGRES_DB_NAME=${var.postgres_db}\" >> /containers/.env",
      "sudo echo \"POSTGRES_HOST=${var.postgres_host}\" >> /containers/.env",
      "sudo echo \"POSTGRES_PORT=${var.postgres_port}\" >> /containers/.env",

      # AWS credentials
      "sudo echo \"[default]\naws_access_key_id=${var.aws_access_key}\naws_secret_access_key=${var.aws_secret_key}\" | sudo tee /home/ubuntu/.aws/credentials >/dev/null",
      "sudo echo \"[default]\nregion=${var.aws_region}\noutput=json\" | sudo tee /home/ubuntu/.aws/config >/dev/null",
      "sudo chown -R ubuntu:ubuntu /home/ubuntu/.aws",
      "sudo chmod 700 /home/ubuntu/.aws",
      "sudo chmod 600 /home/ubuntu/.aws/credentials /home/ubuntu/.aws/config",
    ]
  }

  # Copiando contenido del docker-compose a EC2
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./keys/olimpo_app_key")
      host        = self.public_ip
      timeout     = "5m"
    }
    source      = "./containers/docker-compose.yml"
    destination = "/containers/docker-compose.yml"
  }
}

resource "time_sleep" "wait_for_setup" {
  create_duration = "120s"
  depends_on      = [aws_instance.olimpo_server]
}

resource "null_resource" "setup_app" {
  depends_on = [time_sleep.wait_for_setup]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./keys/olimpo_app_key")
      host        = aws_instance.olimpo_server.public_ip
      timeout     = "10m"
    }

    inline = [
      "cd /containers",

      #Verificamos que Docker esté corriendo
      "echo 'Verificando Docker...'",
      "sudo systemctl status docker || sudo systemctl start docker",
      "while ! docker info >/dev/null 2>&1; do echo 'Esperando Docker...'; sleep 2; done",

      #Login a ECR
      "aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 086143043522.dkr.ecr.us-east-2.amazonaws.com",

      #Levantar contenedores
      "docker compose up -d"
    ]
  }
}
