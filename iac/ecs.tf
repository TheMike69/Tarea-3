variable "app_port" {
  description = "Puerto HTTP en el que escucha la aplicacion dentro del contenedor"
  type        = number
  default     = 80

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535 && floor(var.app_port) == var.app_port
    error_message = "El puerto debe ser un entero entre 1 y 65535."
  }
}

variable "app_health_check_path" {
  description = "Ruta HTTP de la aplicacion que devuelve 200 para el health check"
  type        = string
  default     = "/"
}

data "aws_caller_identity" "current" {}

resource "aws_lb" "app" {
  name               = "tarea3-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name = "tarea3-alb"
  }

  depends_on = [aws_route_table_association.public]
}

resource "aws_lb_target_group" "app" {
  name        = "tarea3-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = var.app_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "tarea3-app-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/tarea3-app"
  retention_in_days = 7

  tags = {
    Name = "tarea3-app-logs"
  }
}

# Fargate usa este rol para descargar la imagen y enviar logs.
resource "aws_iam_role" "ecs_execution" {
  name = "tarea3-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:us-east-1:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })

  tags = {
    Name = "tarea3-ecs-execution-role"
  }
}

resource "aws_iam_role_policy" "ecs_execution" {
  name = "tarea3-ecr-pull-and-logs"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuthentication"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PullApplicationImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid      = "WriteApplicationLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      },
    ]
  })
}

resource "aws_ecs_cluster" "app" {
  name = "tarea3-cluster"

  tags = {
    Name = "tarea3-cluster"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "tarea3-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = var.app_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "app"
        }
      }
      stopTimeout = 30
    }
  ])

  tags = {
    Name = "tarea3-app-task"
  }
}

# Dos tareas, cada una con un contenedor; ECS equilibra las zonas disponibles.
# La imagen :latest debe haberse subido a ECR antes de iniciar el servicio.
resource "aws_ecs_service" "app" {
  name                               = "tarea3-app-service"
  cluster                            = aws_ecs_cluster.app.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = 2
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  availability_zone_rebalancing      = "ENABLED"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  tags = {
    Name = "tarea3-app-service"
  }

  # Espera las rutas y asociaciones privadas, los NAT y su salida publica.
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.ecs_execution,
    aws_route_table.private,
    aws_route_table_association.private,
    aws_route_table_association.public,
    aws_vpc_security_group_ingress_rule.alb_http,
    aws_vpc_security_group_egress_rule.alb_to_ecs,
    aws_vpc_security_group_ingress_rule.ecs_from_alb,
    aws_vpc_security_group_egress_rule.ecs_outbound,
  ]
}

output "alb_url" {
  description = "URL publica de la aplicacion a traves del ALB"
  value       = "http://${aws_lb.app.dns_name}"
}
