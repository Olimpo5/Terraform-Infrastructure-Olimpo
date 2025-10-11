# main.tf

# ===================================================================
# RED (VPC)
# Tu propia sección privada y aislada en la nube de AWS.
# ===================================================================

resource "aws_vpc" "olimpo_vpc" {
  cidr_block = "10.0.0.0/16" # Rango de IPs para toda nuestra red

  # Habilitamos la resolución de DNS para que los servicios se puedan encontrar por nombre
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "olimpo-vpc-${var.aws_environment}"
  }
}

# Obtenemos la lista de Zonas de Disponibilidad (AZs) en la región actual
# para hacer nuestro despliegue resiliente a fallos.
data "aws_availability_zones" "available" {}

# Creamos 2 subredes PÚBLICAS para recursos de cara a internet (Balanceador de Carga)
resource "aws_subnet" "olimpo_public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.olimpo_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.olimpo_vpc.cidr_block, 8, count.index) # Crea subredes como 10.0.0.0/24, 10.0.1.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "olimpo-public-subnet-${count.index + 1}-${var.aws_environment}"
  }
}

# Creamos 2 subredes PRIVADAS para recursos protegidos (Base de Datos y Contenedores)
resource "aws_subnet" "olimpo_private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.olimpo_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.olimpo_vpc.cidr_block, 8, count.index + 2) # Crea subredes como 10.0.2.0/24, 10.0.3.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "olimpo-private-subnet-${count.index + 1}-${var.aws_environment}"
  }
}

# Puerta de enlace para que las subredes PÚBLICAS accedan a internet
resource "aws_internet_gateway" "olimpo_igw" {
  vpc_id = aws_vpc.olimpo_vpc.id
  tags = {
    Name = "olimpo-igw-${var.aws_environment}"
  }
}

# Tabla de rutas para las subredes PÚBLICAS
resource "aws_route_table" "olimpo_public_rt" {
  vpc_id = aws_vpc.olimpo_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Todo el tráfico hacia internet...
    gateway_id = aws_internet_gateway.olimpo_igw.id # ...pasa por la puerta de enlace
  }

  tags = {
    Name = "olimpo-public-rt-${var.aws_environment}"
  }
}

# Asociamos la tabla de rutas a las subredes PÚBLICAS
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.olimpo_public_subnet[count.index].id
  route_table_id = aws_route_table.olimpo_public_rt.id
}# main.tf (continuación)

# ===================================================================
# GRUPOS DE SEGURIDAD (FIREWALLS)
# ===================================================================

# 1. Security Group para el Balanceador de Carga (ALB)
# Permite tráfico web (HTTP) desde cualquier lugar de internet.
resource "aws_security_group" "olimpo_alb_sg" {
  name        = "olimpo-alb-sg-${var.aws_environment}"
  description = "Permite trafico HTTP al Balanceador de Carga"
  vpc_id      = aws_vpc.olimpo_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80 # Puerto HTTP
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1" # Permite toda la salida
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "olimpo-alb-sg-${var.aws_environment}"
  }
}

# 2. Security Group para el Servicio ECS (Tus contenedores)
# Solo permite tráfico que VENGA del Balanceador de Carga.
resource "aws_security_group" "olimpo_ecs_sg" {
  name        = "olimpo-ecs-sg-${var.aws_environment}"
  description = "Permite trafico desde el ALB a los contenedores ECS"
  vpc_id      = aws_vpc.olimpo_vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 80 # Puerto de la aplicación en el contenedor
    to_port         = 80
    security_groups = [aws_security_group.olimpo_alb_sg.id] # ¡IMPORTANTE! Solo acepta tráfico del ALB
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "olimpo-ecs-sg-${var.aws_environment}"
  }
}

# 3. Security Group para la Base de Datos RDS (MySQL)
# Solo permite tráfico que VENGA de tus contenedores.
resource "aws_security_group" "olimpo_rds_sg" {
  name        = "olimpo-rds-sg-${var.aws_environment}"
  description = "Permite trafico desde ECS a la base de datos RDS"
  vpc_id      = aws_vpc.olimpo_vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 3306 # Puerto de MySQL
    to_port         = 3306
    security_groups = [aws_security_group.olimpo_ecs_sg.id] # ¡IMPORTANTE! Solo acepta tráfico de los contenedores
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "olimpo-rds-sg-${var.aws_environment}"
  }
}
