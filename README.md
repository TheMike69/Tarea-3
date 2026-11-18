# Tarea 3

Aplicación estática con Nginx y una infraestructura AWS definida con Terraform.

- `app/`: página, Dockerfile e instrucciones de ejecución local.
- `iac/`: VPC, EC2, ECR, ECS Fargate, ALB, RDS y rol de GitHub Actions.
- `.github/workflows/ecr.yml`: construcción, comprobación HTTP y publicación en ECR.

## Pipeline

Cada push a `main` y cada PR dirigido a `main` construye una imagen Linux AMD64 y comprueba que Nginx responde correctamente. La imagen probada se transfiere al job de publicación como un artefacto con retención de un día.

- Push a `main`: publica una etiqueta única `main-<sha>-<run>-<attempt>` y actualiza `latest`.
- PR del mismo repositorio: publica `pr-<numero>-<run>-<attempt>`, sin modificar `latest`.
- PR de forks o Dependabot: construye y prueba, pero no recibe credenciales AWS ni publica.
- Ejecución manual: disponible desde Actions; publica únicamente desde `main`.

La autenticación usa OIDC: no requiere guardar claves de acceso AWS en GitHub. El ARN del rol y el número de cuenta en el workflow son identificadores, no contraseñas. El rol solo tiene permisos de publicación sobre `tarea3-app`.

La política de ECR conserva las dos imágenes más recientes en total, incluidas las de PR; varias publicaciones de PR pueden hacer que una imagen anterior con `latest` expire. La limpieza es asíncrona. Publicar una imagen no actualiza automáticamente las tareas ECS: para eso se requiere un nuevo despliegue del servicio.

## Infraestructura

Requisitos: Terraform, AWS CLI autenticado y Docker para pruebas locales.

```powershell
terraform -chdir=iac init
terraform -chdir=iac plan
terraform -chdir=iac apply
```

Revisa el plan antes de aplicarlo: la infraestructura completa crea recursos facturables, incluidos NAT Gateways, ALB, Fargate y RDS. Proporciona `ssh_allowed_cidr` con tu IP pública seguida de `/32`. La instancia EC2 utiliza el par de claves `tarea1-key`, que debe existir en `us-east-1`.

El archivo local `iac/terraform.tfstate` debe conservarse y respaldarse de forma segura; está excluido de Git. También se excluyen `.tfvars`, claves privadas, archivos `.env` y proveedores descargados. `.terraform.lock.hcl` sí se versiona.

Si la cuenta ya tiene un proveedor OIDC de GitHub, impórtalo a `aws_iam_openid_connect_provider.github` en lugar de crear otro. Para otra cuenta/repositorio, ajusta la confianza OIDC en `iac/github_actions.tf` y `AWS_ROLE_ARN` en el workflow.

Consulta [app/README.md](app/README.md) para probar la aplicación y publicar manualmente.
