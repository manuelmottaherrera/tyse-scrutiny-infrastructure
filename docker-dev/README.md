# Entorno de Desarrollo 100% Dockerizado

Ejecuta todo el ecosistema Tyse Scrutiny en Docker. **NO necesitas instalar Java, Maven ni Node** en tu computador. Solo necesitas:

- **Docker Desktop** (con WSL2 si usas Windows)
- **git**

## Setup inicial (una sola vez)

### 1. Clonar los repositorios

Todos los repos deben ser hermanos en el mismo directorio:

```bash
mkdir ~/tyse-scrutiny && cd ~/tyse-scrutiny

git clone git@github.com:manuelmottaherrera/tyse-scrutiny-infrastructure.git
git clone git@github.com:manuelmottaherrera/tyse-scrutiny-gateway.git
git clone git@github.com:manuelmottaherrera/tyse-scrutiny-micro-divipol.git
git clone git@github.com:manuelmottaherrera/tyse-scrutiny-micro-scrutiny.git
git clone git@github.com:manuelmottaherrera/tyse-scrutiny-micro-notification.git
```

La estructura debe quedar:

```
~/tyse-scrutiny/
├── tyse-scrutiny-infrastructure/
│   └── docker-dev/              ← Aquí están los scripts
├── tyse-scrutiny-gateway/
├── tyse-scrutiny-micro-divipol/
├── tyse-scrutiny-micro-scrutiny/
└── tyse-scrutiny-micro-notification/
```

### 2. Arrancar

```bash
cd tyse-scrutiny-infrastructure/docker-dev
./start.sh
```

La primera vez tarda **~10-15 minutos** (descarga imágenes Docker + dependencias Maven/npm). Las siguientes veces tarda **~1-2 minutos** gracias al cache.

## Uso diario

```bash
# Arrancar todo
./start.sh

# Arrancar solo un servicio (+ sus dependencias)
./start.sh gateway
./start.sh divipol
./start.sh scrutiny
./start.sh notification

# Solo infraestructura (Consul, Kafka, MinIO, MailHog, BDs)
./start.sh infra

# Ver logs de un servicio
./logs.sh gateway-backend
./logs.sh gateway-frontend
./logs.sh divipol
./logs.sh scrutiny
./logs.sh notification

# Parar todo
./stop.sh

# Parar y eliminar todos los datos (BDs, cache, etc.)
docker compose -f docker-compose.docker-dev.yml down -v
```

## URLs

| Servicio | URL |
|----------|-----|
| Frontend (React) | http://localhost:9000 |
| API Gateway | http://localhost:8080 |
| Consul UI | http://localhost:8500 |
| MinIO Console | http://localhost:9001 (tyseadmin / tyseadmin123) |
| MailHog | http://localhost:8025 |

## Hot Reload

Cuando editas código, los cambios se aplican automáticamente:

- **Archivos .java** → Spring DevTools reinicia el backend (~3-5 segundos)
- **Archivos .tsx/.ts** → Webpack aplica los cambios en el navegador al instante

## Trabajar con Claude Code

1. Abre tu terminal en el repo que quieras modificar (ej: `cd tyse-scrutiny-gateway`)
2. Lanza Claude Code
3. Claude edita los archivos → Docker detecta los cambios y reinicia
4. Verifica en el navegador

## Notas para Windows + WSL

- **Los repos DEBEN estar dentro de WSL** (ej: `~/tyse-scrutiny/`), NO en `/mnt/c/Users/...`. Si los pones en el disco de Windows, Docker será extremadamente lento.
- Docker Desktop debe tener habilitada la integración con WSL2.

## Solución de problemas

### "No space left on device"
```bash
docker system prune -a
```

### Un servicio no arranca
```bash
# Ver logs del servicio que falla
./logs.sh gateway-backend

# Reiniciar solo ese servicio
docker compose -f docker-compose.docker-dev.yml restart gateway-backend
```

### Quiero empezar de cero
```bash
docker compose -f docker-compose.docker-dev.yml down -v
./start.sh
```
