# Tarea 3 — Nginx

Página estática servida por Nginx en el puerto 80. La ruta `/` devuelve HTTP 200 y sirve como health check del ALB. Esta demostración no necesita conectarse a RDS.

## Probar localmente

Desde la carpeta `app`, con Docker Desktop iniciado:

```powershell
docker build --platform linux/amd64 -t tarea3-app:latest .
docker run --rm -p 8080:80 --name tarea3-app tarea3-app:latest
```

Abre http://localhost:8080. Presiona Ctrl+C para detener el contenedor.

## Publicar en ECR

Después de crear el repositorio con Terraform, ejecuta desde `app` con credenciales de AWS configuradas:

```powershell
$repositoryUrl = terraform -chdir=../iac output -raw ecr_repository_url
$registryHost = $repositoryUrl.Split('/')[0]
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $registryHost
docker build --platform linux/amd64 -t tarea3-app:latest .
docker tag tarea3-app:latest "${repositoryUrl}:latest"
docker push "${repositoryUrl}:latest"
```

Si el servicio ECS ya existe, inicia un nuevo despliegue para cargar la imagen publicada:

```powershell
aws ecs update-service --region us-east-1 --cluster tarea3-cluster --service tarea3-app-service --force-new-deployment
```
