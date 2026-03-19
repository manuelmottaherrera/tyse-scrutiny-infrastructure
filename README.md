# Tyse Infrastructure

Infraestructura compartida para todos los microservicios del ecosistema Tyse Scrutiny.

Este repositorio contiene **dos ambientes**:

| Directorio | Propósito | Dónde se usa |
|------------|-----------|--------------|
| `/` (raíz) | Infraestructura para **desarrollo local** | Máquina de cada desarrollador |
| `/dev/` | Ecosistema completo para **servidor de desarrollo** | Servidor 192.168.0.58 |

## Infraestructura Local (desarrollo individual)

Levanta solo los servicios compartidos. Cada microservicio corre con `./mvnw` por separado.

### Servicios

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| Consul | 8500 | Service discovery y configuración centralizada |
| Consul Config Loader | - | Carga automática de config en Consul K/V |
| Kafka | 9092 | Message broker (KRaft mode, sin Zookeeper) |
| MinIO | 9000 (API) / 9001 (UI) | Object storage S3-compatible para PDFs |
| MinIO Init | - | Creación automática de buckets al arranque |
| MailHog | 1025 (SMTP) / 8025 (UI) | Servidor SMTP de desarrollo para capturar emails |

### Inicio rápido

```bash
# Levantar infraestructura
docker compose up -d

# Verificar
docker compose ps

# Detener
docker compose down

# Detener y eliminar datos
docker compose down -v
```

### Uso con microservicios

```bash
# 1. Levantar infraestructura compartida (una vez)
cd tyse-scrutiny-infrastructure
docker compose up -d

# 2. Levantar PostgreSQL de cada microservicio
cd ../tyse-scrutiny-gateway
docker compose -f src/main/docker/postgresql.yml up -d

cd ../tyse-scrutiny-micro-divipol
docker compose -f src/main/docker/postgresql.yml up -d

cd ../tyse-scrutiny-micro-scrutiny
docker compose -f src/main/docker/postgresql.yml up -d

# 3. Arrancar los microservicios (cada uno en su terminal)
cd tyse-scrutiny-gateway && ./mvnw
cd tyse-scrutiny-micro-divipol && ./mvnw
cd tyse-scrutiny-micro-scrutiny && ./mvnw
```

---

## Ambiente de Desarrollo (servidor 192.168.0.58)

Despliega **todo el ecosistema** en Docker: infraestructura + bases de datos + microservicios + nginx.

### Servicios del ambiente dev

| Servicio | Puerto Externo | Descripción |
|----------|---------------|-------------|
| **Nginx** | 80 | Reverse proxy → Gateway |
| Consul | 8510 | Service discovery |
| Kafka | 9102 | Message broker |
| MinIO | 9000 / 9001 | Object storage |
| MailHog | 1035 / 8035 | Email testing |
| PostgreSQL Gateway | 5432 | BD del gateway |
| PostgreSQL Divipol | 5433 | BD de divipol |
| PostgreSQL Scrutiny | 5434 | BD de scrutiny |
| Gateway | (interno) | Expuesto via nginx :80 |
| Divipol | (interno) | Accesible via gateway routing |
| Scrutiny | (interno) | Accesible via gateway routing |
| Mock Pipeline | (interno) | Generador de datos E14 |
| Notification | (interno) | Envío de notificaciones |

### Setup inicial

```bash
# 1. Clonar el repo en el servidor
ssh web-tyse
cd /home/tyse
git clone git@github.com:manuelmottaherrera/tyse-scrutiny-infrastructure.git tyse-scrutiny

# 2. Configurar variables de entorno
cd tyse-scrutiny/dev
cp .env.dev.example .env.dev
nano .env.dev  # Completar passwords y JWT_SECRET

# 3. Desplegar
./scripts/deploy-dev.sh
```

### Despliegue y operaciones

```bash
# Desplegar todo (pull + restart)
./dev/scripts/deploy-dev.sh

# Solo descargar imágenes nuevas
./dev/scripts/deploy-dev.sh --pull-only

# Reiniciar sin pull
./dev/scripts/deploy-dev.sh --restart

# Desplegar un servicio específico
./dev/scripts/deploy-dev.sh --service gateway

# Verificar salud de servicios
./dev/scripts/health-check.sh

# Ver logs de un servicio
docker compose -f dev/docker-compose.dev.yml --env-file dev/.env.dev logs -f gateway

# Detener todo
docker compose -f dev/docker-compose.dev.yml --env-file dev/.env.dev down
```

### Despliegue remoto (desde tu máquina local)

```bash
ssh web-tyse 'cd /home/tyse/tyse-scrutiny && ./dev/scripts/deploy-dev.sh'
```

### Perfil local-dev

Para desarrollar localmente conectado a los servicios del servidor dev:

```bash
# En tu máquina local, ejecutar cualquier micro apuntando al servidor
cd tyse-scrutiny-gateway
./mvnw -Dspring-boot.run.profiles=local-dev
```

Los puertos de BD, Consul y Kafka del servidor dev están expuestos a la LAN.

---

## Kafka Topics

| Topic | Particiones | Descripción |
|-------|-------------|-------------|
| `e14-pdf-uploaded` | 3 | PDF subido a MinIO, listo para OCR |
| `e14-ocr-completed` | 3 | OCR completado, listo para limpieza |
| `e14-data-cleaned` | 3 | Datos E14 limpios, listos para persistencia |
| `e14-anomaly-detected` | 3 | Anomalía detectada, lista para notificación |
| `e14-processing-status` | 3 | Estado del procesamiento de documentos |
| `notification-request` | 3 | Solicitud de notificación (email, WhatsApp, SMS) |
| `sse-topic` | 1 | Topic legacy para Server-Sent Events |

## MinIO Buckets

| Bucket | Descripción |
|--------|-------------|
| `e14-pdfs` | PDFs originales subidos por el frontend |
| `e14-processed` | Archivos procesados (auditoría) |

- Consola MinIO: http://localhost:9001
- Usuario: `tyseadmin` / Password: `tyseadmin123`

## Consul

- UI: http://localhost:8500
- Configuración compartida en `consul/central-server-config/application.yml`
- Contiene JWT secret compartido entre microservicios

## MailHog

- UI: http://localhost:8025
- Puerto SMTP: 1025
- Sin autenticación
