# Tyse Infrastructure

Infraestructura compartida para todos los microservicios del ecosistema Tyse Scrutiny.

Este repositorio contiene **tres ambientes**:

| Directorio | Propósito | Dónde se usa |
|------------|-----------|--------------|
| `/` (raíz) | Infraestructura para **desarrollo local** (requiere Java/Node instalados) | Máquina de cada desarrollador |
| `/docker-dev/` | **Desarrollo local 100% Dockerizado** (solo Docker + git) | Vibe coders, devs sin Java/Node |
| `/dev/` | Ecosistema completo para **servidor de desarrollo** | Servidor 192.168.0.58 |

## Infraestructura Local (desarrollo individual)

Levanta solo los servicios compartidos. Cada microservicio corre con `./mvnw` por separado. Requiere Java 17 y Maven instalados.

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

## Desarrollo Local 100% Dockerizado (`/docker-dev/`)

**No requiere instalar Java, Maven ni Node.** Solo Docker + git.

Compila desde source dentro de contenedores con hot reload (Spring DevTools + Webpack HMR).

```bash
cd docker-dev
./start.sh              # Todo el ecosistema (~10 min primera vez, ~1 min después)
./start.sh gateway      # Solo gateway + dependencias
./logs.sh gateway-backend
./stop.sh
```

Ver instrucciones completas en [`docker-dev/README.md`](docker-dev/README.md).

---

## Ambiente de Desarrollo (servidor 192.168.0.58)

Despliega **todo el ecosistema** en Docker: infraestructura + bases de datos + microservicios + nginx.

### Servicios del ambiente dev

| Servicio | Puerto Externo | Descripción |
|----------|---------------|-------------|
| **Nginx** | 8090 | Reverse proxy → Gateway |
| Consul | 8510 | Service discovery |
| Kafka | 9102 | Message broker |
| MinIO | 9000 / 9001 | Object storage |
| MailHog | 1035 / 8035 | Email testing |
| PostgreSQL Gateway | 5432 | BD del gateway |
| PostgreSQL Divipol | 5433 | BD de divipol |
| PostgreSQL Scrutiny | 5434 | BD de scrutiny |
| Gateway | (interno) | Expuesto via nginx :8090 |
| Divipol | (interno) | Accesible via gateway routing |
| Scrutiny | (interno) | Accesible via gateway routing |
| Notification | (interno) | Envío de notificaciones |

### Setup inicial

El self-hosted runner de GitHub Actions debe estar configurado en el servidor. El `.env.dev` se genera automáticamente desde GitHub Secrets durante el deploy.

Los secrets necesarios se configuran en GitHub → Settings → Secrets: `DEV_GATEWAY_DB_PASSWORD`, `DEV_DIVIPOL_DB_PASSWORD`, `DEV_SCRUTINY_DB_PASSWORD`, `DEV_JWT_SECRET`, `DEV_CORS_ALLOWED_ORIGINS`, `DEV_RECAPTCHA_SITE_KEY`, `DEV_RECAPTCHA_SECRET_KEY`, `DEV_MINIO_PASSWORD`.

### Despliegue (CI/CD vía GitHub Actions)

El despliegue se gestiona exclusivamente por GitHub Actions, garantizando que solo se despliega lo que está en la rama `develop`.

**Triggers automáticos:**
- Push a `develop` que modifique archivos en `dev/*`

**Trigger manual:**
- Desde GitHub Actions → `Deploy to Dev Server` → Run workflow
- Permite seleccionar servicio específico: `all`, `gateway`, `divipol`, `scrutiny`, `notification`

El workflow corre en un self-hosted runner, genera `.env.dev` desde GitHub Secrets, y ejecuta health checks post-deploy.

### Operaciones en el servidor

```bash
# Ver logs de un servicio
ssh web-tyse 'cd /home/tyse/tyse-scrutiny && docker compose -f docker-compose.dev.yml --env-file .env.dev logs -f gateway'

# Ver estado de los contenedores
ssh web-tyse 'cd /home/tyse/tyse-scrutiny && docker compose -f docker-compose.dev.yml --env-file .env.dev ps'

# Detener todo (usar solo si es necesario, el redeploy lo hace GHA)
ssh web-tyse 'cd /home/tyse/tyse-scrutiny && docker compose -f docker-compose.dev.yml --env-file .env.dev down'
```

### Sincronización producción → desarrollo

Descarga BDs de producción, sanitiza datos sensibles e importa en dev.

```bash
# Configurar credenciales de producción
cp dev/.env.sync.example dev/.env.sync
nano dev/.env.sync

# Sincronizar todas las BDs
./dev/scripts/sync-prod-to-dev.sh

# Solo una BD específica
./dev/scripts/sync-prod-to-dev.sh --db gateway

# Dry-run: solo exportar sin importar
./dev/scripts/sync-prod-to-dev.sh --dry-run
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
