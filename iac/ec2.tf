variable "key_name" {
  description = "Nombre de un par de claves EC2 existente en us-east-1"
  type        = string
}

# Imagen oficial de Ubuntu 24.04 LTS publicada por Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "nginx" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = "tarea1-key"
  subnet_id                   = aws_subnet.public["us-east-1a"].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nginx.id]
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get -o Acquire::Retries=5 update
    apt-get -o Acquire::Retries=5 install -y nginx
    systemctl enable --now nginx
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "tarea3-ubuntu-nginx"
  }

  # La instalacion requiere que la salida a Internet ya este disponible.
  depends_on = [
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.nginx_outbound,
  ]
}

output "nginx_public_ip" {
  description = "IP publica de la instancia Ubuntu con Nginx"
  value       = aws_instance.nginx.public_ip
}

output "nginx_url" {
  description = "URL disponible cuando termine la instalacion inicial de Nginx"
  value       = "http://${aws_instance.nginx.public_ip}"
}
