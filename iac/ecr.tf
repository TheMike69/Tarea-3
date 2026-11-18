resource "aws_ecr_repository" "app" {
  name                 = "tarea3-app"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  # Permite publicar nuevas versiones como :latest para el servicio ECS.
  image_tag_mutability_exclusion_filter {
    filter      = "latest"
    filter_type = "WILDCARD"
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tarea3-app"
  }
}

# Conserva las dos imagenes mas recientes, tengan o no etiquetas.
# La limpieza es asincrona; no es un limite inmediato al subir imagenes.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar las 2 imagenes mas recientes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_url" {
  description = "URL del repositorio para etiquetar y subir imagenes de la aplicacion"
  value       = aws_ecr_repository.app.repository_url
}
