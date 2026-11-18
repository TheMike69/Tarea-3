variable "ssh_allowed_cidr" {
  description = "IP publica autorizada para SSH en formato IPv4/32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr)) && can(regex("/32$", var.ssh_allowed_cidr))
    error_message = "Indica una direccion IPv4 con prefijo /32."
  }
}

resource "aws_security_group" "nginx" {
  name        = "tarea3-nginx-sg"
  description = "Acceso HTTP publico a Nginx"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "tarea3-nginx-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nginx_http" {
  security_group_id = aws_security_group.nginx.id
  description       = "HTTP desde Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "nginx_ssh" {
  security_group_id = aws_security_group.nginx.id
  description       = "SSH desde la IP autorizada"
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "nginx_outbound" {
  security_group_id = aws_security_group.nginx.id
  description       = "Salida para DNS y descarga de paquetes"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "alb" {
  name        = "tarea3-alb-sg"
  description = "HTTP publico al ALB y salida hacia los contenedores"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "tarea3-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  description                  = "Trafico y health checks hacia la aplicacion"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_security_group" "ecs_tasks" {
  name        = "tarea3-ecs-tasks-sg"
  description = "Entrada a los contenedores exclusivamente desde el ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "tarea3-ecs-tasks-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Puerto de la aplicacion solo desde el ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_egress_rule" "ecs_outbound" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Salida via NAT para descargar imagenes y enviar logs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "rds_mysql" {
  name        = "tarea3-rds-mysql-sg"
  description = "MySQL privado accesible solamente desde las tareas ECS"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "tarea3-rds-mysql-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_ecs" {
  security_group_id            = aws_security_group.rds_mysql.id
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  description                  = "MySQL desde los contenedores ECS"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}
