# Plataforma Web de Alta Disponibilidad en AWS

[![AWS](https://img.shields.io/badge/AWS-CloudFormation-orange)](https://aws.amazon.com/cloudformation/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![License](https://img.shields.io/badge/Licencia-MIT-blue)](LICENSE)
[![English](https://img.shields.io/badge/Language-English-blue)](README.md)

**Infraestructura como Codigo Lista para Produccion, Aprendizaje y Portafolio**

---

## Tabla de Contenidos

1. [Descripcion General](#descripcion-general)
2. [Por Que Este Proyecto](#por-que-este-proyecto)
3. [Arquitectura](#arquitectura)
4. [Inicio Rapido](#inicio-rapido)
5. [Estructura del Proyecto](#estructura-del-proyecto)
6. [Configuracion](#configuracion)
7. [Flujo de Despliegue](#flujo-de-despliegue)
8. [Guia de Despliegue con Terraform](#guia-de-despliegue-con-terraform)
9. [Verificacion y Evidencia](#verificacion-y-evidencia)
10. [Capturas de Pantalla](#capturas-de-pantalla)
11. [Seguridad](#seguridad)
12. [Dominios del AWS Cloud Practitioner](#dominios-del-aws-cloud-practitioner)
13. [Ejemplos de Salida de Scripts](#ejemplos-de-salida-de-scripts)
14. [Solucion de Problemas](#solucion-de-problemas)
15. [Descargas](#descargas)
16. [Lecciones Aprendidas](#lecciones-aprendidas)
17. [Convenciones del Repositorio](#convenciones-del-repositorio)
18. [Licencia](#licencia)

---

## Descripcion General

Este repositorio proporciona un ejemplo completo y funcional de una **plataforma web de alta disponibilidad** en AWS. Esta disenado para:

- **Estudiantes** aprendiendo arquitectura cloud e Infraestructura como Codigo
- **Profesionales** construyendo su portafolio DevOps con codigo real y desplegable
- **Equipos** que necesitan una implementacion de referencia con mejores practicas de AWS

Todo funciona de inmediato. Clona el repositorio, agrega tus credenciales de AWS y despliega una infraestructura de nivel produccion en menos de 15 minutos.

---

## Por Que Este Proyecto

Construir infraestructura cloud es complejo. Este proyecto resuelve desafios comunes:

| Desafio | Solucion |
|---------|----------|
| "No se por donde empezar" | Guia de Inicio Rapido paso a paso con comandos para copiar y pegar |
| "Mi lab tiene permisos restringidos" | Pre-configurado para AWS Academy con LabInstanceProfile |
| "Necesito probar mi trabajo" | Scripts de recoleccion de evidencia y 20 capturas incluidas |
| "Olvido eliminar recursos" | Scripts de destruccion automatizada previenen cargos inesperados |
| "Quiero aprender Terraform tambien" | Alternativa completa en Terraform con tutorial |
| "Los prompts interactivos me confunden" | Todos los prompts muestran valores por defecto; presiona Enter para aceptar |

### Caracteristicas Principales

| Caracteristica | Descripcion |
|----------------|-------------|
| **Multi-AZ** | Recursos distribuidos en 2 Zonas de Disponibilidad para tolerancia a fallos |
| **Auto Scaling** | Instancias EC2 escalan de 1-3 segun demanda |
| **Application Load Balancer** | Distribucion de trafico en capa 7 con health checks |
| **Subnets Privadas** | Capa de aplicacion aislada del internet publico |
| **DynamoDB** | NoSQL administrado con encriptacion en reposo |
| **CloudWatch** | Monitoreo de utilizacion de CPU con alarmas |
| **VPC Endpoint** | Acceso privado opcional a DynamoDB |

---

## Arquitectura

### Diagrama de Infraestructura

```mermaid
flowchart TB
    subgraph AWS["AWS Region (us-west-2)"]
        subgraph VPC["VPC 10.0.0.0/16"]
            IGW[Internet Gateway]
            
            subgraph PublicTier["Subnets Publicas"]
                PUB1["Subnet Publica 1<br/>10.0.1.0/24<br/>AZ1"]
                PUB2["Subnet Publica 2<br/>10.0.2.0/24<br/>AZ2"]
                ALB["Application Load Balancer<br/>HTTP:80"]
                NAT["NAT Gateway"]
                EIP["Elastic IP"]
            end
            
            subgraph PrivateTier["Subnets Privadas"]
                PRIV1["Subnet Privada 1<br/>10.0.11.0/24<br/>AZ1"]
                PRIV2["Subnet Privada 2<br/>10.0.12.0/24<br/>AZ2"]
                ASG["Auto Scaling Group"]
                EC2A["Instancia EC2"]
                EC2B["Instancia EC2"]
            end
            
            subgraph DataTier["Capa de Datos"]
                DDB["Tabla DynamoDB<br/>Encriptacion: Habilitada"]
                VPCE["VPC Endpoint<br/>(Opcional)"]
            end
        end
        
        CW["Alarma CloudWatch<br/>CPU > 70%"]
    end
    
    Internet((Internet)) --> IGW
    IGW --> ALB
    ALB --> EC2A
    ALB --> EC2B
    EC2A --> NAT
    EC2B --> NAT
    NAT --> IGW
    ASG --> EC2A
    ASG --> EC2B
    EC2A -.-> VPCE
    EC2B -.-> VPCE
    VPCE --> DDB
    EC2A -.-> CW
    EC2B -.-> CW
```

### Distribucion de Red

| Componente | CIDR/Detalles | Proposito |
|------------|---------------|-----------|
| **VPC** | 10.0.0.0/16 | Contenedor de red aislado |
| **Subnet Publica 1** | 10.0.1.0/24 (AZ1) | ALB, NAT Gateway |
| **Subnet Publica 2** | 10.0.2.0/24 (AZ2) | Redundancia del ALB |
| **Subnet Privada 1** | 10.0.11.0/24 (AZ1) | Instancias EC2 |
| **Subnet Privada 2** | 10.0.12.0/24 (AZ2) | Instancias EC2 |

### Grupos de Seguridad

| Grupo de Seguridad | Entrada | Salida | Proposito |
|--------------------|---------|--------|-----------|
| **ALB SG** | HTTP:80 desde 0.0.0.0/0 | Todo | Load balancer publico |
| **EC2 SG** | HTTP:80 solo desde ALB SG | Todo | Instancias privadas, sin SSH |

### Integracion con DynamoDB

Cada instancia EC2 se registra en DynamoDB al iniciar y muestra todas las instancias registradas en la pagina web:

```mermaid
sequenceDiagram
    participant Usuario
    participant ALB
    participant EC2
    participant DynamoDB

    Note over EC2: Instancia inicia via UserData
    EC2->>DynamoDB: put-item (instance_id, az, ip, timestamp)
    
    Usuario->>ALB: HTTP GET /
    ALB->>EC2: Reenviar solicitud
    EC2->>DynamoDB: scan (obtener todas las instancias)
    DynamoDB-->>EC2: Lista de instancias registradas
    EC2-->>ALB: HTML con datos de instancias
    ALB-->>Usuario: Pagina web mostrando todas las instancias
```

La pagina web muestra:
- Metadatos de la instancia actual (ID, AZ, IP privada)
- Nombre de la tabla DynamoDB
- Todas las instancias registradas del escaneo de DynamoDB
- Resumen de la arquitectura

Esto demuestra:
- Conectividad de EC2 a DynamoDB via VPC Endpoint (privado, sin internet)
- Reconocimiento de instancias a traves del Auto Scaling Group
- Generacion de contenido dinamico desde consultas a la base de datos

---

## Inicio Rapido

### Resumen del Flujo de Despliegue

```mermaid
flowchart LR
    A[1. Configurar .env] --> B[2. Desplegar]
    B --> C[3. Verificar]
    C --> D[4. Usar Aplicacion]
    D --> E[5. Recolectar Evidencia]
    E --> F[6. Destruir]
```

| Paso | Script | Que Hace |
|------|--------|----------|
| Configurar | Manual | Crear `.env.aws-lab` con tus credenciales de AWS |
| Desplegar | `fresh-start.sh` | Valida plantilla, crea todos los recursos AWS |
| Verificar | `verify.sh` | Confirma que el stack esta saludable, prueba endpoint del ALB |
| Usar | Navegador | Acceder a la aplicacion web via URL DNS del ALB |
| Evidencia | `evidence.sh` | Captura info del stack, recursos y resultados de pruebas |
| Destruir | `destroy.sh` | Elimina todos los recursos para evitar cargos |

### Prerrequisitos

- AWS CLI v2 instalado ([Guia de Instalacion](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- Credenciales AWS con permisos de CloudFormation, EC2, ELB, DynamoDB
- Bash 4.0+ (Linux/macOS/WSL)

### Compatibilidad con Ambiente de Laboratorio

Este proyecto esta disenado para **ambientes de laboratorio AWS** con permisos IAM restringidos:

| Restriccion | Solucion |
|-------------|----------|
| No puede crear Roles IAM | Usa **LabInstanceProfile** pre-existente con **LabRole** |
| Tipos de instancia limitados | Usa t2.micro/t3.micro (permitidos) |
| Maximo 9 instancias EC2 | ASG limitado a 1-3 instancias |
| Capacidad reservada de DynamoDB deshabilitada | Usa facturacion bajo demanda |
| VPC Endpoint puede fallar | Opcional - configura `CREATE_DDB_VPC_ENDPOINT=no` si es necesario |

### Paso 1: Configurar Ambiente

El archivo `.env.aws-lab` almacena tus credenciales AWS y parametros de despliegue. Este archivo esta en gitignore y nunca se sube al repositorio.

```bash
# Copiar la configuracion de ejemplo
cp .env.aws-lab.example .env.aws-lab

# Editar con tus credenciales (usa nano, vim, o VS Code)
nano .env.aws-lab
```

**Variables requeridas** (obtenlas de tu AWS Academy Lab o consola IAM):

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_SESSION_TOKEN=tu-session-token    # Requerido para credenciales temporales/lab
AWS_REGION=us-west-2
```

**Variables opcionales** (los valores por defecto funcionan para la mayoria de despliegues):

```bash
STACK_NAME=ha-web-platform              # Nombre del stack CloudFormation
RESOURCE_PREFIX=infra-ha-web-dev        # Prefijo para todos los nombres de recursos
INSTANCE_TYPE=t2.micro                  # Tipo de instancia EC2
DESIRED_CAPACITY=2                      # Numero de instancias EC2
CREATE_DDB_VPC_ENDPOINT=yes             # Configurar 'no' si la creacion del endpoint falla
```

### Paso 2: Desplegar Infraestructura

```bash
# Recomendado: Despliegue completo desde cero (salta confirmaciones)
bash scripts/fresh-start.sh --force

# Alternativa: Despliegue interactivo (pregunta por cada parametro)
bash scripts/deploy.sh
```

**Salida esperada:**
```
[INFO] Step 1/3: Checking for existing stack...
[INFO] Step 2/3: Validating CloudFormation template...
[SUCCESS] Template is valid.
[INFO] Step 3/3: Deploying stack...
[INFO] Still deploying... (2m 30s / 15m 0s elapsed, status: CREATE_IN_PROGRESS)
[SUCCESS] Stack deployment completed. Final status: CREATE_COMPLETE
```

### Paso 3: Verificar Despliegue

```bash
bash scripts/verify.sh
```

**Salida esperada:**
```
[SUCCESS] Stack ha-web-platform is in CREATE_COMPLETE state.
[INFO] ALB DNS: ha-web-platform-alb-123456789.us-west-2.elb.amazonaws.com
[SUCCESS] ALB is responding to HTTP requests (attempt 1/10, 0m 15s elapsed)
```

### Paso 4: Recolectar Evidencia

```bash
bash scripts/evidence.sh
```

La evidencia se guarda en el directorio `logs/evidence/`.

### Paso 5: Destruir Infraestructura

```bash
bash scripts/destroy.sh
```

**Importante**: Siempre destruye los recursos despues de probar para evitar cargos.

---

## Estructura del Proyecto

```
├── README.md                    # Documentacion en ingles
├── README_ES.md                 # Este archivo - documentacion en espanol
├── .env.aws-lab                 # Configuracion (credenciales, parametros)
├── .env.aws-lab.example         # Plantilla de configuracion
│
├── iac/
│   └── main.yaml                # Plantilla CloudFormation (UserData inline)
│
├── terraform/                   # Alternativa Terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh
│
├── scripts/
│   ├── fresh-start.sh           # Orquestador de despliegue completo
│   ├── deploy.sh                # Despliegue CloudFormation
│   ├── verify.sh                # Verificacion de salud
│   ├── evidence.sh              # Recoleccion de evidencia
│   ├── destroy.sh               # Eliminacion del stack
│   ├── cleanup.sh               # Limpieza de stacks fallidos
│   ├── menu.sh                  # Menu interactivo
│   └── lib/
│       └── common.sh            # Funciones compartidas
│
├── logs/                        # Todos los logs organizados aqui
│   ├── .gitkeep                 # Preserva directorios vacios en git
│   ├── deploy/                  # Logs de despliegue
│   ├── destroy/                 # Logs de destruccion
│   ├── verify/                  # Logs de verificacion
│   ├── evidence/                # Archivos de evidencia
│   └── menu/                    # Logs de operaciones del menu
│
├── app/                         # Codigo de aplicacion
│   └── haweb_app.py             # Aplicacion Flask (implementacion de referencia)
│
└── docs/                        # Documentacion adicional
    └── screenshots/             # Capturas de evidencia
```

---

## Configuracion

### Variables de Ambiente (.env.aws-lab)

| Variable | Requerida | Defecto | Descripcion |
|----------|-----------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | Si | - | Clave de acceso AWS |
| `AWS_SECRET_ACCESS_KEY` | Si | - | Clave secreta AWS |
| `AWS_SESSION_TOKEN` | Solo lab | - | Token de sesion temporal |
| `AWS_REGION` | Si | us-west-2 | Region de AWS |
| `STACK_NAME` | No | ha-web-platform | Nombre del stack CloudFormation |
| `RESOURCE_PREFIX` | No | ha-web-platform | Prefijo para nombres de recursos |
| `ENVIRONMENT` | No | dev | Etiqueta de ambiente (dev/test/prod) |
| `INSTANCE_TYPE` | No | t2.micro | Tipo de instancia EC2 |
| `AMI_ID` | No | ami-022bee044edfca8f1 | AMI Amazon Linux 2 |
| `DESIRED_CAPACITY` | No | 2 | Instancias deseadas del ASG |
| `MIN_SIZE` | No | 1 | Instancias minimas del ASG |
| `MAX_SIZE` | No | 3 | Instancias maximas del ASG |
| `VPC_CIDR` | No | 10.0.0.0/16 | Bloque CIDR de la VPC |
| `CREATE_DDB_VPC_ENDPOINT` | No | yes | Crear VPC endpoint para DynamoDB |

### Prioridad de Parametros

Los scripts usan este orden de prioridad:
1. **Argumentos CLI** (mayor prioridad)
2. **Variables de ambiente** (desde .env.aws-lab)
3. **Valores por defecto** (respaldo)

---

## Flujo de Despliegue

### Modo Interactivo vs No Interactivo

Todos los scripts soportan ambos modos:

| Modo | Cuando se Usa | Comportamiento |
|------|---------------|----------------|
| **Interactivo** | Ejecutando en terminal | Pregunta confirmacion, permite cambiar parametros |
| **No Interactivo** | Sin TTY detectado, o flag `--non-interactive` | Usa valores por defecto o argumentos CLI, sin preguntas |

### Entendiendo los Prompts

Cada prompt te dice exactamente que hacer:

**Prompts de entrada de texto:**
```
Stack name [default: ha-web-platform] (press Enter for default):
```
- Presiona Enter solo para usar el valor por defecto mostrado en corchetes
- O escribe un nuevo valor y presiona Enter para cambiar

**Prompts de confirmacion (defecto Si):**
```
Continue with deployment? (Y/n) - press Enter to confirm, or type 'n' to cancel:
```
- La `Y` mayuscula indica que Si es el defecto
- Presiona Enter solo para aceptar y continuar
- Escribe `n` y presiona Enter para cancelar

**Prompts de confirmacion (defecto No):**
```
Continue? (y/N) - type 'y' and Enter to confirm, or just Enter for No:
```
- La `N` mayuscula indica que No es el defecto
- Presiona Enter solo para cancelar (defecto seguro)
- Escribe `y` y presiona Enter para proceder

### Saltar Confirmaciones

```bash
# Usa --force para saltar todas las confirmaciones
bash scripts/fresh-start.sh --force

# Usa --yes para saltar solo la confirmacion final
bash scripts/deploy.sh --yes

# Usa --non-interactive para pipelines CI/CD
bash scripts/deploy.sh --non-interactive --yes
```

### Flujo Automatizado (fresh-start.sh)

```mermaid
flowchart LR
    A[Inicio] --> B{Stack Existente?}
    B -->|Si| C[Eliminar Stack]
    B -->|No| D[Validar Plantilla]
    C --> D
    D --> E[Desplegar Stack]
    E --> F{Exito?}
    F -->|Si| G[Mostrar Outputs]
    F -->|No| H[Mostrar Errores]
    G --> I[Fin]
    H --> I
```

### Estimaciones de Tiempo

| Fase | Duracion | Descripcion |
|------|----------|-------------|
| Validacion de plantilla | ~30 segundos | Verificacion de sintaxis y parametros |
| VPC + Networking | 1-2 minutos | VPC, subnets, IGW, NAT |
| Grupos de Seguridad | ~30 segundos | Grupos de seguridad de ALB y EC2 |
| ALB + Target Group | 2-3 minutos | Load balancer y listeners |
| Launch Template + ASG | 2-3 minutos | Instancias EC2 con user data |
| DynamoDB | ~30 segundos | Creacion de tabla |
| Health checks | 2-3 minutos | Registro de targets en ALB |
| **Total** | **10-15 minutos** | Despliegue completo |

---

## Guia de Despliegue con Terraform

Esta seccion proporciona un tutorial paso a paso para desplegar la misma infraestructura usando Terraform en lugar de CloudFormation. Ambas herramientas crean recursos identicos.

### Prerrequisitos

1. Instalar Terraform (v1.0+):
```bash
# Linux/WSL
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verificar instalacion
terraform --version
```

2. Configurar credenciales AWS (igual que CloudFormation):
```bash
export AWS_ACCESS_KEY_ID="tu_access_key"
export AWS_SECRET_ACCESS_KEY="tu_secret_key"
export AWS_SESSION_TOKEN="tu_session_token"  # Para ambientes de laboratorio
export AWS_REGION="us-west-2"
```

### Estructura de Archivos Terraform

```
terraform/
├── main.tf           # Todas las definiciones de recursos
├── variables.tf      # Declaraciones de variables de entrada
├── outputs.tf        # Definiciones de valores de salida
└── user_data.sh      # Plantilla de script de bootstrap para EC2
```

| Archivo | Proposito |
|---------|-----------|
| `main.tf` | Define todos los recursos AWS: VPC, subnets, ALB, ASG, DynamoDB, CloudWatch |
| `variables.tf` | Declara variables de entrada con tipos, valores por defecto y descripciones |
| `outputs.tf` | Expone DNS del ALB, VPC ID y otros valores despues del despliegue |
| `user_data.sh` | Plantilla de script shell renderizada con `templatefile()` para instancias EC2 |

### Paso 1: Inicializar Terraform

```bash
cd terraform/

# Descargar plugins de providers e inicializar backend
terraform init
```

Salida esperada:
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Paso 2: Revisar el Plan

```bash
# Vista previa de cambios sin aplicar
terraform plan
```

Esto muestra todos los recursos que seran creados:
```
Plan: 26 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name = (known after apply)
  + vpc_id       = (known after apply)
```

### Paso 3: Aplicar Configuracion

```bash
# Crear todos los recursos (escribe 'yes' cuando se solicite)
terraform apply
```

O saltar confirmacion:
```bash
terraform apply -auto-approve
```

### Paso 4: Verificar Despliegue

```bash
# Mostrar outputs
terraform output

# Probar el ALB
curl -s "$(terraform output -raw alb_dns_name)/health.html"
```

### Paso 5: Destruir Infraestructura

```bash
# Eliminar todos los recursos
terraform destroy
```

### Personalizar Variables

Crea un archivo `terraform.tfvars` (en gitignore) para sobrescribir valores por defecto:

```hcl
# terraform/terraform.tfvars
aws_region       = "us-east-1"
environment      = "prod"
resource_prefix  = "myapp-prod"
instance_type    = "t3.micro"
desired_capacity = 3
```

O pasa variables via linea de comandos:
```bash
terraform apply -var="environment=prod" -var="desired_capacity=3"
```

### Comparacion CloudFormation vs Terraform

| Aspecto | CloudFormation | Terraform |
|---------|----------------|-----------|
| **Sintaxis** | YAML/JSON | HCL (HashiCorp Configuration Language) |
| **Gestion de Estado** | Administrado por AWS | Archivo local o backend remoto |
| **Deteccion de Drift** | Incorporado | `terraform plan` muestra drift |
| **Multi-Cloud** | Solo AWS | AWS, Azure, GCP y mas |
| **Rollback** | Automatico en fallo | Manual (destruir y re-aplicar) |
| **Curva de Aprendizaje** | Conceptos especificos de AWS | Patrones universales de IaC |

### Conceptos Clave de Terraform Usados

| Concepto | Ejemplo en Este Proyecto |
|----------|--------------------------|
| **Data Sources** | `data.aws_ami.amazon_linux_2` encuentra la AMI mas reciente dinamicamente |
| **Resources** | `aws_vpc.haweb`, `aws_lb.alb` definen infraestructura |
| **Variables** | `var.instance_type` permite personalizacion |
| **Outputs** | `output.alb_dns_name` expone el endpoint del ALB |
| **templatefile()** | Renderiza `user_data.sh` con sustitucion de variables |
| **Creacion Condicional** | `count = var.create_ddb_endpoint ? 1 : 0` |
| **Tags** | Todos los recursos etiquetados para asignacion de costos e identificacion |

---

## Verificacion y Evidencia

### Verificacion de Salud

El script `verify.sh` realiza:

1. **Verificacion de Estado del Stack**: Confirma estado CREATE_COMPLETE
2. **Resolucion DNS del ALB**: Obtiene endpoint del load balancer
3. **Verificacion HTTP de Salud**: Prueba endpoint /health.html con reintentos

### Recoleccion de Evidencia

El script `evidence.sh` captura:

| Tipo de Evidencia | Archivo | Descripcion |
|-------------------|---------|-------------|
| Info del stack | `logs/evidence/stack-info-*.json` | CloudFormation describe-stacks |
| Recursos del stack | `logs/evidence/stack-resources-*.json` | Todos los recursos del stack |
| Eventos del stack | `logs/evidence/stack-events-*.json` | Linea de tiempo del despliegue |
| Salud del ALB | `logs/evidence/alb-health-*.txt` | Prueba de respuesta HTTP |
| Prueba DynamoDB | `logs/evidence/ddb-test-*.json` | Verificacion de put/get item |

---

## Capturas de Pantalla

### Estructura del Proyecto

![Estructura del Proyecto](docs/screenshots/01-project-structure.png)

### AWS CloudFormation y Computo

![Stack CloudFormation](docs/screenshots/02-aws-cloudformation.png)

![Instancias EC2](docs/screenshots/03-aws-ec2-instances.png)

![Application Load Balancer](docs/screenshots/04-aws-alb.png)

![Auto Scaling Group](docs/screenshots/05-aws-asg.png)

![Salud del Target Group](docs/screenshots/14-aws-target-group.png)

### Base de Datos y Monitoreo

![Tabla DynamoDB](docs/screenshots/06-aws-dynamodb.png)

![Items de DynamoDB](docs/screenshots/15-aws-dynamodb-items.png)

![Alarma CloudWatch](docs/screenshots/16-aws-cloudwatch-alarm.png)

### Networking

![VPC](docs/screenshots/08-aws-vpc.png)

![Subnets](docs/screenshots/09-aws-subnets.png)

![Tablas de Rutas](docs/screenshots/10-aws-route-tables.png)

![Internet Gateway](docs/screenshots/11-aws-igw.png)

![NAT Gateway](docs/screenshots/12-aws-nat.png)

### Seguridad

![Grupos de Seguridad](docs/screenshots/13-aws-security-groups.png)

### Aplicacion Web

El nombre DNS del ALB es generado dinamicamente por AWS y se muestra despues del despliegue:

```
[OK] Stack deployment completed.
ALB DNS: ha-web-HaWeb-KmrDxwHWSml1-855691521.us-west-2.elb.amazonaws.com
```

**Como acceder a la aplicacion:**

1. Copia el DNS del ALB de la salida del despliegue
2. Abre tu navegador y navega a: `http://TU-DNS-DEL-ALB/`
3. La pagina web muestra:

| Seccion | Informacion Mostrada |
|---------|---------------------|
| Metadatos de Instancia | ID de instancia EC2 actual, Zona de Disponibilidad, IP privada, tipo de instancia |
| Integracion DynamoDB | Nombre de tabla, region AWS, estado de conexion |
| Instancias Registradas | Todas las instancias EC2 que se han registrado en DynamoDB |
| Resumen de Arquitectura | Explicacion del balanceo de carga y estado de auto-refresco |

4. Refresca la pagina multiples veces para observar el balanceo de carga (diferentes IDs de instancia)

![Aplicacion Web Funcionando](docs/screenshots/07-webapp-running.png)

![Respuesta con Balanceo de Carga](docs/screenshots/17-webapp-loadbalanced.png)

La captura de Items de DynamoDB muestra los datos de registro de instancias que aparecen en la pagina web:

![Detalle de Items DynamoDB](docs/screenshots/15-aws-dynamodb-items.png)

### Operaciones de Terminal

![Script de Verificacion](docs/screenshots/18-terminal-verify.png)

![Proceso de Destruccion](docs/screenshots/19-terminal-destroy.png)

![Proceso de Despliegue](docs/screenshots/20-terminal-deploy.png)

---

## Seguridad

### Seguridad de Red

- **Sin Acceso SSH**: Las instancias EC2 no tienen puerto SSH abierto
- **Subnets Privadas**: Capa de aplicacion aislada del internet
- **Egreso NAT**: Acceso a internet solo de salida para actualizaciones
- **Solo ALB**: Trafico entrante restringido al load balancer

### Seguridad de Datos

- **Encriptacion DynamoDB**: Encriptacion del lado del servidor habilitada
- **VPC Endpoint**: Acceso privado opcional (sin transito por internet)
- **Credenciales**: Nunca se suben al repositorio (.gitignore)

### Estrategia de Etiquetado

Todos los recursos estan etiquetados con:

| Etiqueta | Ejemplo | Proposito |
|----------|---------|-----------|
| `Name` | ha-web-platform-vpc | Identificacion de recursos |
| `Project` | ha-web-platform | Asignacion de costos |
| `Environment` | dev | Separacion de ambientes |
| `Description` | Core VPC for HA Web Platform | Descripcion funcional |
| `Tier` | Network / Compute / Database | Capa de arquitectura |

---

## Dominios del AWS Cloud Practitioner

Este proyecto demuestra los cuatro dominios de la certificacion AWS Cloud Practitioner con implementaciones reales y funcionales. Cada concepto no es solo teorico, puedes verlo en accion.

### Dominio 1: Conceptos de Cloud (24% del examen)

| Concepto | Donde Verlo | Que Demuestra |
|----------|-------------|---------------|
| **Alta Disponibilidad** | Despliegue Multi-AZ | Instancias EC2 distribuidas en `us-west-2a` y `us-west-2b`. Si una AZ falla, la otra continua sirviendo trafico |
| **Escalabilidad** | Auto Scaling Group | `MinSize: 2, MaxSize: 2, DesiredCapacity: 2` - facilmente ajustable via parametros |
| **Elasticidad** | ASG + CloudWatch | Alarma de CPU al 80% puede disparar acciones de scale-out (configurado para notificacion) |
| **Tolerancia a Fallos** | Health Checks del ALB | Instancias no saludables removidas automaticamente de la rotacion en 30 segundos |
| **Infraestructura Global** | Despliegue Regional | Plantilla despliega en `us-west-2` (Oregon) pero funciona en cualquier region con ajuste de AMI |
| **Responsabilidad Compartida** | LabInstanceProfile | AWS administra hardware EC2; nosotros administramos OS, aplicacion y grupos de seguridad |

**Comando de evidencia:**
```bash
bash scripts/verify.sh --yes  # Muestra 2/2 targets saludables en diferentes AZs
```

### Dominio 2: Seguridad y Cumplimiento (30% del examen)

| Concepto | Donde Verlo | Que Demuestra |
|----------|-------------|---------------|
| **Defensa en Profundidad** | Arquitectura de red | 4 capas: Internet -> ALB (publico) -> EC2 (privado) -> DynamoDB (endpoint) |
| **Minimo Privilegio** | Grupos de seguridad | ALB SG permite HTTP:80 desde 0.0.0.0/0; EC2 SG permite solo desde ALB SG |
| **Encriptacion en Reposo** | Tabla DynamoDB | `SSESpecification.SSEEnabled: true` con claves administradas por AWS |
| **Aislamiento de Red** | Subnets privadas | Instancias EC2 no tienen IPs publicas; salida via NAT Gateway unicamente |
| **Mejores Practicas IAM** | LabInstanceProfile | Rol pre-existente con permisos acotados para acceso a DynamoDB |
| **VPC Endpoint** | Endpoint opcional | Acceso privado a DynamoDB sin atravesar internet |

**Arquitectura de seguridad:**
```
Internet -> Grupo de Seguridad ALB (puerto 80) -> Grupo de Seguridad EC2 -> Subnet Privada
                                                                                ↓
                                              VPC Endpoint (opcional) -> DynamoDB
```

**Comando de evidencia:**
```bash
bash scripts/evidence.sh --yes  # Muestra grupos de seguridad y configuracion de red
```

### Dominio 3: Tecnologia y Servicios (34% del examen)

| Categoria | Servicios | Detalles de Implementacion |
|-----------|-----------|---------------------------|
| **Computo** | EC2, ASG, Launch Template | Amazon Linux 2, servidor HTTP Python, bootstrap UserData |
| **Networking** | VPC, Subnets (4), IGW, NAT, Route Tables, ALB | VPC personalizada con CIDR `10.0.0.0/16`, separacion de capas publica/privada |
| **Base de Datos** | DynamoDB | Tabla bajo demanda con partition key `id`, instancias se auto-registran |
| **Gestion** | CloudFormation | Plantilla unica crea 27 recursos con orden de dependencias apropiado |
| **Monitoreo** | CloudWatch | Alarma de utilizacion de CPU al 80% de umbral |
| **Alternativa IaC** | Terraform | Implementacion paralela completa para aprendizaje multi-cloud |

**Conteo de recursos por categoria:**
```
Networking:  13 recursos (VPC, Subnets, Routes, NAT, IGW)
Computo:      6 recursos (ASG, Launch Template, ALB, Listener, Target Group)
Seguridad:    2 recursos (ALB SG, EC2 SG)
Base Datos:   2 recursos (Tabla DynamoDB, VPC Endpoint)
Monitoreo:    1 recurso  (Alarma CloudWatch)
───────────────────────────────────────────────────────────────
Total:       27 recursos creados por CloudFormation
```

### Dominio 4: Facturacion y Precios (12% del examen)

| Practica | Implementacion | Impacto en Costos |
|----------|----------------|-------------------|
| **Uso de Capa Gratuita** | Instancias `t2.micro` | 750 horas/mes gratis (primeros 12 meses) |
| **Precios Bajo Demanda** | DynamoDB PAY_PER_REQUEST | Sin aprovisionamiento de capacidad; paga solo por lo que usas |
| **Etiquetado de Recursos** | Etiquetas `Environment` y `Name` | Habilita filtrado en Cost Explorer e informes de asignacion |
| **Control de Costos** | Script `destroy.sh` | Un comando elimina los 27 recursos, sin recursos huerfanos |
| **Visibilidad de Costos** | Todas las operaciones registradas | Pista de auditoria para revision y optimizacion de costos |
| **NAT Unico** | Un NAT Gateway | ~$45/mes de ahorro vs NAT por AZ (aceptable para dev/lab) |

**Estimacion de costos (ambiente de laboratorio):**
```
Componente               Costo Mensual (Bajo Demanda)
─────────────────────────────────────────────────────
EC2 t2.micro x 2         $0.00 (Capa Gratuita) o ~$18
NAT Gateway              ~$32 (por hora + transferencia de datos)
ALB                      ~$22 (por hora + LCU)
DynamoDB                 ~$0.25 (uso minimo)
─────────────────────────────────────────────────────
Total Estimado           ~$55/mes (o ~$35 con Capa Gratuita)
```

**Comando de limpieza:**
```bash
bash scripts/destroy.sh --yes  # Elimina todo, muestra timer: "Stack deleted in 7m 17s"
```

---

## Ejemplos de Salida de Scripts

Los scripts de automatizacion proporcionan retroalimentacion visual clara para todas las operaciones. Aqui hay ejemplos de salida real:

### Salida de Deploy

```
============================================================
  CLOUDFORMATION DEPLOYMENT
============================================================

--- Configuration ---
  Template:                iac/main.yaml
  Stack Name:              ha-web-platform
  Region:                  us-west-2

--- Deployment Progress ---
[2025-12-30 05:28:42] [INFO] Initiating stack create/update...

[2025-12-30 05:32:23] [OK]   Deployment completed in 3m 41s
  Final Status:            CREATE_COMPLETE

--- Stack Outputs ---
  ALB DNS:                 ha-web-HaWeb-xxx.us-west-2.elb.amazonaws.com
  VPC ID:                  vpc-0363aa62c8547f081
  Resources Created:       27
```

### Salida de Verify

```
============================================================
  STEP 2: TARGET GROUP HEALTH
============================================================

--- Target Health Status ---
  TARGET ID              PORT       HEALTH          REASON
  ------------------------------------------------------------
  i-0185c314c73209863    80         healthy         -
  i-0496497f8d65a8632    80         healthy         -

[OK] All targets healthy: 2/2
```

### Salida de Evidence

```
============================================================
  STEP 4: DYNAMODB EVIDENCE
============================================================

--- Write/Read Test ---
  Test Item ID:            evidence-1767071113
  Write:                   SUCCESS
  Read:                    SUCCESS

--- Registered EC2 Instances ---
  INSTANCE ID            AZ              PRIVATE IP       LAUNCH TIME
  ----------------------------------------------------------------------
  i-0496497f8d65a8632    us-west-2a      10.0.11.90       2025-12-30T04:51:02Z
  i-0185c314c73209863    us-west-2b      10.0.12.202      2025-12-30T04:53:16Z
```

### Salida de Destroy

```
============================================================
  DELETING INFRASTRUCTURE
============================================================

--- Deletion Progress ---
  [00:00 / 15:00] DELETE_IN_PROGRESS
    > HaWebAlbListener                    DELETE_IN_PROGRESS
    > HaWebCpuAlarmHigh                   DELETE_IN_PROGRESS
  [05:15 / 15:00] DELETE_IN_PROGRESS

[OK] Stack deleted successfully in 7m 17s

============================================================
  DELETION COMPLETE
============================================================
  Stack:                   ha-web-platform
  Status:                  DELETED
```

---

## Solucion de Problemas

### Problemas Comunes

**Stack en estado ROLLBACK_COMPLETE:**
```bash
bash scripts/cleanup.sh --stack-name ha-web-platform --force
bash scripts/fresh-start.sh --force
```

**Creacion de VPC Endpoint falla (AccessDenied):**
```bash
# Editar .env.aws-lab
CREATE_DDB_VPC_ENDPOINT=no

# Re-desplegar
bash scripts/fresh-start.sh --force
```

**ALB no responde:**
```bash
# Verificar estado del stack
bash scripts/verify.sh

# Ver eventos recientes
aws cloudformation describe-stack-events \
  --stack-name ha-web-platform \
  --region us-west-2 \
  --query 'StackEvents[:10]'
```

### Ubicaciones de Logs

| Tipo de Log | Ruta |
|-------------|------|
| Despliegue | `logs/deploy/` |
| Destruccion | `logs/destroy/` |
| Verificacion | `logs/verify/` |
| Evidencia | `logs/evidence/` |
| Fresh start | `logs/fresh-start-*.log` |

---

## Descargas

### Plantilla CloudFormation

- [iac/main.yaml](iac/main.yaml) - Plantilla CloudFormation completa

### Plantillas Terraform

- [terraform/main.tf](terraform/main.tf) - Configuracion principal
- [terraform/variables.tf](terraform/variables.tf) - Variables de entrada
- [terraform/outputs.tf](terraform/outputs.tf) - Definiciones de salida
- [terraform/user_data.sh](terraform/user_data.sh) - Script de bootstrap EC2

### Scripts

- [scripts/fresh-start.sh](scripts/fresh-start.sh) - Despliegue completo
- [scripts/deploy.sh](scripts/deploy.sh) - Despliegue CloudFormation
- [scripts/verify.sh](scripts/verify.sh) - Verificacion de salud
- [scripts/evidence.sh](scripts/evidence.sh) - Recoleccion de evidencia
- [scripts/destroy.sh](scripts/destroy.sh) - Eliminacion del stack

---

## Lecciones Aprendidas

### Lo Que Construimos

Este proyecto implementa una plataforma web de alta disponibilidad completa que demuestra patrones de arquitectura cloud del mundo real:

1. **Capa de Red**: VPC personalizada con subnets publicas y privadas a traves de dos Zonas de Disponibilidad, proporcionando aislamiento de red y tolerancia a fallos.

2. **Capa de Computo**: Auto Scaling Group con instancias EC2 ejecutando una aplicacion web Python, automaticamente distribuidas entre AZs.

3. **Balanceo de Carga**: Application Load Balancer distribuyendo trafico HTTP con health checks asegurando que solo instancias saludables reciban trafico.

4. **Capa de Datos**: Tabla DynamoDB donde las instancias EC2 se registran al iniciar, demostrando integracion con base de datos y reconocimiento de instancias.

5. **Monitoreo**: Alarma CloudWatch para utilizacion de CPU, lista para disparar acciones de escalado o notificaciones.

6. **Seguridad**: Defensa en profundidad con grupos de seguridad permitiendo solo trafico necesario (HTTP desde ALB a EC2, salida para actualizaciones).

### Enfoque Tecnico

| Aspecto | Decision | Razon |
|---------|----------|-------|
| Herramienta IaC | CloudFormation primario, Terraform alternativo | CloudFormation nativo de AWS, Terraform para portabilidad multi-cloud |
| Instance Profile | LabInstanceProfile (pre-existente) | Labs de AWS Academy restringen creacion de roles IAM |
| NAT Gateway | NAT unico en AZ1 | Optimizacion de costos para ambiente de laboratorio (produccion usaria NAT por AZ) |
| DynamoDB | Capacidad bajo demanda | Sin planificacion de capacidad necesaria, precios pay-per-request |
| VPC Endpoint | Opcional via parametro | Algunos roles de laboratorio restringen creacion de endpoints |

### Aprendizajes Clave

1. **Restricciones del Ambiente de Laboratorio**: Los labs de AWS Academy tienen permisos IAM restringidos. Nos adaptamos usando LabInstanceProfile pre-existente en lugar de crear roles IAM personalizados.

2. **Consistencia en Nombres de Recursos**: Usar un patron de prefijo de recursos (ej., `infra-ha-web-dev`) a traves de todos los recursos simplifica identificacion y limpieza.

3. **Orden de Eliminacion de CloudFormation**: NAT Gateways deben eliminarse antes de Elastic IPs. CloudFormation maneja esto automaticamente pero toma tiempo.

4. **Depuracion de UserData**: Los logs de UserData de EC2 van a `/var/log/cloud-init-output.log`. Esencial para solucionar problemas de bootstrap.

5. **Dependencia de AMI por Region**: Los IDs de AMI son especificos por region. La misma imagen Amazon Linux 2 tiene diferentes IDs en us-east-1 vs us-west-2.

### Mejoras Potenciales

| Area | Estado Actual | Mejora |
|------|---------------|--------|
| HTTPS | Solo HTTP | Agregar certificado ACM y listener HTTPS |
| DNS | Nombre DNS del ALB | Agregar zona hospedada Route53 con dominio amigable |
| Escalado | Capacidad manual | Agregar politicas de escalado por seguimiento de objetivo |
| Secretos | Variables de ambiente | Usar AWS Secrets Manager para datos sensibles |
| CI/CD | Despliegue manual | Agregar pipeline de GitHub Actions para despliegues automatizados |
| Multi-NAT | NAT Gateway unico | Agregar NAT por AZ para verdadera alta disponibilidad |
| Backup | Sin backup | Habilitar recuperacion punto-en-tiempo de DynamoDB |

---

## Convenciones del Repositorio

### Organizacion de Archivos

Este repositorio sigue convenciones estandar para mantenibilidad:

| Convencion | Proposito |
|------------|-----------|
| `scripts/lib/` | Funciones de biblioteca compartidas usadas por todos los scripts |
| `logs/` | Todos los logs organizados por tipo de operacion (deploy, verify, destroy) |
| `docs/screenshots/` | Capturas de evidencia para documentacion |
| `iac/` | Plantillas CloudFormation (IaC primario) |
| `terraform/` | Configuracion Terraform (IaC alternativo) |

### La Convencion .gitkeep

Git no rastrea directorios vacios. Los archivos `.gitkeep` son archivos placeholder usados para preservar la estructura de directorios en control de versiones:

```
logs/
├── .gitkeep           # Preserva directorio logs/
├── deploy/
│   └── .gitkeep       # Preserva subdirectorio deploy/
├── destroy/
│   └── .gitkeep       # Preserva subdirectorio destroy/
├── evidence/
│   └── .gitkeep       # Preserva subdirectorio evidence/
└── menu/
    └── .gitkeep       # Preserva subdirectorio menu/
```

Por que importa:
- Los scripts esperan que estos directorios existan para salida de logs
- Nuevos usuarios clonando el repositorio obtienen la estructura correcta
- Los archivos de log reales estan en gitignore (datos sensibles/efimeros)
- `.gitkeep` es una convencion de la comunidad, no una caracteristica de Git

### Archivos en .gitignore

| Patron | Razon |
|--------|-------|
| `.env.aws-lab` | Contiene credenciales AWS |
| `logs/` | Logs de despliegue efimeros |
| `*.tfstate*` | Estado de Terraform contiene datos sensibles |
| `*.tfvars` | Puede contener secretos (excepto `.tfvars.example`) |
| `.terraform/` | Plugins de providers descargados |
| `__pycache__/` | Bytecode de Python |

---

## Licencia

Este proyecto esta licenciado bajo la Licencia MIT. Ver [LICENSE](LICENSE) para detalles.

---

## Autor

Creado por [SvillarroelZ](https://github.com/SvillarroelZ)

Este proyecto demuestra patrones de infraestructura AWS de nivel produccion para propositos educativos y demostracion de portafolio.
