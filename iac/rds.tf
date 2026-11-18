resource "aws_db_subnet_group" "mysql" {
  name        = "tarea3-mysql-subnets"
  description = "Subnets privadas para RDS MySQL"
  subnet_ids  = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name = "tarea3-mysql-subnets"
  }
}

resource "aws_db_instance" "mysql" {
  identifier     = "tarea3-mysql"
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "tarea3"
  username                    = "dbadmin"
  manage_master_user_password = true
  port                        = 3306

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds_mysql.id]
  publicly_accessible    = false
  multi_az               = false
  availability_zone      = "us-east-1a"

  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  # Para eliminar la BD, desactiva primero la proteccion en un apply separado.
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "tarea3-mysql-final"

  tags = {
    Name = "tarea3-mysql"
  }
}

output "rds_address" {
  description = "Host privado de MySQL, accesible desde las tareas ECS"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "Puerto de MySQL"
  value       = aws_db_instance.mysql.port
}

output "rds_database_name" {
  description = "Nombre de la base de datos inicial"
  value       = aws_db_instance.mysql.db_name
}

output "rds_master_secret_arn" {
  description = "ARN del secreto administrado por RDS con las credenciales maestras"
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}
