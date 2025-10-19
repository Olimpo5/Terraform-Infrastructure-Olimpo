#CREACION DE UN PAR DE CLAVES
# Creamos un nuevo directorio llamado keys ESTE DIRECTORIO NO SE SUBE A GIT
# Ejecutamos el comando ssh-keygen -t rsa -f ./keys/olimpo_app_key -C "clave-para-acceso-ssh-a-servidor-olimpo"
# Con este comando se crean dos archivos: olimpo_app_key (clave privada) y olimpo_app_key.pub (clave publica)
# La clave privada (olimpo_app_key) es la que utilizaremos para conectarnos via SSH a la instancia EC2
# La clave publica (olimpo_app_key.pub) es la que se sube a AWS
resource "aws_key_pair" "olimpo_app_key" {
  public_key = file("./keys/olimpo_app_key.pub")
  key_name   = var.aws_key_pair_name
}

# CREACION DE UN SECURITY GROUP
# - Asignamos un nombre y una descripcion para nuestro security group
# - Creamos reglas de inbound para el puerto 22 (ssh) 
# - Creamos reglas de outbound para permitir la salida a internet
resource "aws_security_group" "olimpo_sg" {
  name        = var.aws_olimpo_sg
  description = "Permitir las conexiones por SSH"

  # Permisos de entrada
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

  # Permisos de salida
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

# CREACION DE UN EC2
# En esta sentencia de abajo hacemos lo siguiente:
# - Colocamos el id del AMI de ubuntu en la region us-east-2
# - Colocamos el tipo de instancia
# - Colocamos un tag para identificar la instancia
# - Colocamos la llave para conectarnos en la instancia ec2
# - Agregamos el security group a nuestro ec2
# - Agregamos un script que instala docker y otras herramientas de CLI
# - Creamos un provisioner para crear una carpeta /containers con un archivo .env dentro
# - En el segundo provisioner copiamos el archivo docker-compose.yml de nuestra maquina a la carpeta containers
resource "aws_instance" "olimpo_server" {
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

  // PROVISIONERS
  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./keys/olimpo_app_key")
      host        = self.public_ip
    }
    inline = [
      "sudo mkdir /containers",
      "sudo mkdir -p /volumes/nginx/certs",
      "sudo mkdir -p /volumes/nginx/vhostd",
      "sudo mkdir -p /volumes/nginx/html",
      "sudo chmod 777 /volumes/nginx/certs",
      "sudo chmod 777 /volumes/nginx/vhostd",
      "sudo chmod 777 /volumes/nginx/html",
      "mkdir /home/ubuntu/.aws",
      "sudo touch /containers/.env",
      "sudo chmod 777 /containers",
      "sudo chmod 777 /containers/.env",
      "sudo echo \"MAIN_DOMAIN=${var.main_domain}\" >> /containers/.env ",
      "sudo echo \"POSTGRES_USER=${var.postgres_user}\" >> /containers/.env ",
      "sudo echo \"POSTGRES_PASSWORD=${var.postgres_password}\" >> /containers/.env",
      "sudo echo \"POSTGRES_DB_NAME=${var.postgres_db}\" >> /containers/.env",
      "sudo echo \"POSTGRES_HOST=${var.postgres_host}\" >> /containers/.env",
      "sudo echo \"POSTGRES_PORT=${var.postgres_port}\" >> /containers/.env",
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
    }
    source      = "./containers/docker-compose.yml"
    destination = "/containers/docker-compose.yml"
  }
}

resource "time_sleep" "wait_120_seconds" {
  create_duration = "120s"
  depends_on      = [aws_instance.olimpo_app_server]
}

resource "null_resource" "setup_app" {
  depends_on = [time_sleep.wait_120_seconds]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./keys/olimpo_app_key")
      host        = aws_instance.olimpo_app_server.public_ip
    }
    inline = [
      "cd /containers",
      "aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 086143043522.dkr.ecr.us-east-2.amazonaws.com",
      "docker compose up -d"
    ]
  }
}

