# Tyse Infrastructure

Infraestructura compartida para todos los microservicios del ecosistema Tyse Scrutiny.

## Servicios

| Servicio | Puerto | Descripcion |
|----------|--------|-------------|
| Consul | 8500 | Service discovery y configuracion centralizada |
| Consul Config Loader | - | Carga automatica de config en Consul K/V |
| Kafka | 9092 | Message broker (KRaft mode, sin Zookeeper) |
| Kafka Init | - | Creacion automatica de topics al arranque |
| MinIO | 9000 (API) / 9001 (UI) | Object storage S3-compatible para PDFs |
| MinIO Init | - | Creacion automatica de buckets al arranque |
| MailHog | 1025 (SMTP) / 8025 (UI) | Servidor SMTP de desarrollo para capturar emails |

## Inicio rapido

```bash
# Levantar toda la infraestructura
docker compose up -d

# Verificar que todo esta corriendo
docker compose ps

# Ver logs
docker compose logs -f

# Detener todo
docker compose down

# Detener y eliminar volumenes (datos)
docker compose down -v
```

## Kafka Topics

Los siguientes topics se crean **automaticamente** cuando el primer producer/consumer se conecta (KAFKA_AUTO_CREATE_TOPICS_ENABLE=true):

| Topic | Particiones | Descripcion |
|-------|-------------|-------------|
| `e14-pdf-uploaded` | 3 | PDF subido a MinIO, listo para OCR |
| `e14-ocr-completed` | 3 | OCR completado, listo para limpieza |
| `e14-data-cleaned` | 3 | Datos E14 limpios, listos para persistencia |
| `e14-anomaly-detected` | 3 | Anomalia detectada, lista para notificacion |
| `e14-processing-status` | 3 | Estado del procesamiento de documentos |
| `notification-request` | 3 | Solicitud de notificacion (email, WhatsApp, SMS) |
| `sse-topic` | 1 | Topic legacy para Server-Sent Events |

## MinIO Buckets

| Bucket | Descripcion |
|--------|-------------|
| `e14-pdfs` | PDFs originales subidos por el frontend |
| `e14-processed` | Archivos procesados (auditoria) |

**Acceso a la consola MinIO**: http://localhost:9001
- Usuario: `tyseadmin`
- Password: `tyseadmin123`

## Consul

**Acceso a la UI de Consul**: http://localhost:8500

La configuracion compartida se carga automaticamente desde `consul/central-server-config/application.yml`.
Contiene el JWT secret compartido entre todos los microservicios.

## MailHog

**Acceso a la UI de MailHog**: http://localhost:8025

Servidor SMTP de desarrollo que captura todos los emails enviados por los microservicios.
Usado por micro-notification (y temporalmente por el gateway hasta completar la migracion).

- Puerto SMTP: 1025
- No requiere autenticacion

## Uso con microservicios

Cada microservicio debe levantar solo su propia base de datos PostgreSQL.
Los servicios compartidos (Consul, Kafka, MinIO) se levantan **una sola vez** desde aqui.

```bash
# 1. Levantar infraestructura compartida (una vez)
cd tyse-infrastructure
docker compose up -d

# 2. Levantar PostgreSQL de cada microservicio
cd ../tyse-scrutiny-gateway
docker compose -f src/main/docker/postgresql.yml up -d

cd ../tyse-scrutiny-micro-divipol
docker compose -f src/main/docker/postgresql.yml up -d

cd ../tyse-scrutiny-micro-scrutiny
docker compose -f src/main/docker/postgresql.yml up -d

# 3. Arrancar los microservicios
# (cada uno en su terminal)
cd tyse-scrutiny-gateway && ./mvnw
cd tyse-scrutiny-micro-divipol && ./mvnw
cd tyse-scrutiny-micro-scrutiny && ./mvnw
```
