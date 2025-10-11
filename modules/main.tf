# modules/main.tf (VERSIÓN FINAL Y COMPLETA)

# ===================================================================
# RED (VPC)
# ===================================================================

resource "aws_vpc" "olimpo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc-${var.aws_environment}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "olimpo_public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.olimpo_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.olimpo_vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}-${var.aws_environment}"
  }
}

resource "aws_subnet" "olimpo_private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.olimpo_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.olimpo_vpc.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}-${var.aws_environment}"
  }
}

resource "aws_internet_gateway" "olimpo_igw" {
  vpc_id = aws_vpc.olimpo_vpc.id
  tags = {
    Name = "${var.project_name}-igw-${var.aws_environment}"
  }
}

resource "aws_route_table" "olimpo_public_rt" {
  vpc_id = aws_vpc.olimpo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.olimpo_igw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt-${var.aws_environment}"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.olimpo_public_subnet[count.index].id
  route_table_id = aws_route_table.olimpo_public_rt.id
}

# ===================================================================
# GRUPOS DE SEGURIDAD (FIREWALLS)
# ===================================================================

resource "aws_security_group" "olimpo_alb_sg" {
  name        = "${var.project_name}-alb-sg-${var.aws_environment}"
  description = "Permite trafico HTTP al Balanceador de Carga"
  vpc_id      = aws_vpc.olimpo_vpc.id
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-alb-sg-${var.aws_environment}"
  }
}

resource "aws_security_group" "olimpo_ecs_sg" {
  name        = "${var.project_name}-ecs-sg-${var.aws_environment}"
  description = "Permite trafico desde el ALB a los contenedores ECS"
  vpc_id      = aws_vpc.olimpo_vpc.id
  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.olimpo_alb_sg.id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-ecs-sg-${var.aws_environment}"
  }
}

resource "aws_security_group" "olimpo_rds_sg" {
  name        = "${var.project_name}-rds-sg-${var.aws_environment}"
  description = "Permite trafico desde ECS a la base de datos RDS"
  vpc_id      = aws_vpc.olimpo_vpc.id
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [aws_security_group.olimpo_ecs_sg.id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-rds-sg-${var.aws_environment}"
  }
}

# ===================================================================
# REPOSITORIO DE IMÁGENES DOCKER (ECR)
# ===================================================================

resource "aws_ecr_repository" "olimpo_ecr_repo" {
  name                 = "${var.project_name}-${var.aws_environment}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name        = "${var.project_name}-repo-${var.aws_environment}"
    Environment = var.aws_environment
  }
}

# ===================================================================
# CLUSTER DE CONTENEDORES (ECS)
# ===================================================================

resource "aws_ecs_cluster" "olimpo_cluster" {
  name = "${var.project_name}-cluster-${var.aws_environment}"
  tags = {
    Name        = "${var.project_name}-cluster-${var.aws_environment}"
    Environment = var.aws_environment
  }
}

# ===================================================================
# BALANCEADOR DE CARGA (ALB)
# ===================================================================

resource "aws_lb" "olimpo_alb" {
  name               = "${var.project_name}-alb-${var.aws_environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.olimpo_alb_sg.id]
  subnets            = aws_subnet.olimpo_public_subnet[*].id
  tags = {
    Name        = "${var.project_name}-alb-${var.aws_environment}"
    Environment = var.aws_environment
  }
}

resource "aws_lb_target_group" "olimpo_tg" {
  name        = "${var.project_name}-tg-${var.aws_environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.olimpo_vpc.id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name        = "${var.project_name}-tg-${var.aws_environment}"
    Environment = var.aws_environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.olimpo_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.olimpo_tg.arn
  }
}

# ===================================================================
# DEFINICIÓN Y SERVICIO DE LA APLICACIÓN (ECS)
# ===================================================================

resource "aws_ecs_task_definition" "olimpo_task" {
  family                   = "${var.project_name}-task-${var.aws_environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container-${var.aws_environment}"
      image     = "nginx:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ],
      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.olimpo_rds.address
        },
        {
          name  = "DB_NAME"
          value = aws_db_instance.olimpo_rds.db_name
        }
      ],
      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]
    }
  ])
  tags = {
    Name        = "${var.project_name}-task-def-${var.aws_environment}"
    Environment = var.aws_environment
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-execution-role-${var.aws_environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.project_name}-ecs-secrets-policy-${var.aws_environment}"
  description = "Permite a las tareas de ECS leer secretos de Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}

resource "aws_ecs_service" "olimpo_service" {
  name            = "${var.project_name}-service-${var.aws_environment}"
  cluster         = aws_ecs_cluster.olimpo_cluster.id
  task_definition = aws_ecs_task_definition.olimpo_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = aws_subnet.olimpo_private_subnet[*].id
    security_groups = [aws_security_group.olimpo_ecs_sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.olimpo_tg.arn
    container_name   = "${var.project_name}-container-${var.aws_environment}"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.http]
  tags = {
    Name        = "${var.project_name}-service-${var.aws_environment}"
    Environment = var.aws_environment
  }
}

# ===================================================================
# BASE DE DATOS (RDS MySQL)
# ===================================================================

resource "aws_db_subnet_group" "olimpo_rds_subnet_group" {
  name       = "${var.project_name}-rds-sng-${var.aws_environment}"
  subnet_ids = aws_subnet.olimpo_private_subnet[*].id
  tags = {
    Name = "${var.project_name}-rds-sng-${var.aws_environment}"
  }
}

resource "aws_db_instance" "olimpo_rds" {
  identifier             = "${var.project_name}-rds-${var.aws_environment}"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "${var.project_name}db"
  username               = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  password               = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.olimpo_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.olimpo_rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags = {
    Name = "${var.project_name}-rds-${var.aws_environment}"
  }
}

# ===================================================================
# GESTIÓN DE SECRETOS (AWS Secrets Manager)
# ===================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-credentials-${var.aws_environment}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
  })
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}