#!/bin/bash

################################################################################
# Deploy Tyse Scrutiny - Development Server
#
# Despliega todo el ecosistema en Docker en el servidor de desarrollo.
# Ejecuta desde el servidor o remotamente con:
#   ssh web-tyse 'cd /home/tyse/tyse-scrutiny && ./dev/scripts/deploy-dev.sh'
#
# Opciones:
#   --pull-only    Solo descargar imágenes nuevas, sin reiniciar
#   --restart      Reiniciar servicios sin pull
#   --service X    Solo desplegar servicio X (gateway, divipol, scrutiny, mock-pipeline, notification)
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$DEV_DIR/docker-compose.dev.yml"
ENV_FILE="$DEV_DIR/.env.dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
ok()  { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn(){ echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
err() { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }

# Verificaciones
if [ ! -f "$COMPOSE_FILE" ]; then
    err "No se encontró $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    err "No se encontró $ENV_FILE. Copiar de .env.dev.example:"
    echo "  cp $DEV_DIR/.env.dev.example $ENV_FILE"
    exit 1
fi

# Parse argumentos
PULL_ONLY=false
RESTART_ONLY=false
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --pull-only) PULL_ONLY=true; shift ;;
        --restart) RESTART_ONLY=true; shift ;;
        --service) SERVICE="$2"; shift 2 ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
done

COMPOSE_CMD="docker compose -f $COMPOSE_FILE --env-file $ENV_FILE"

log "=== Deploy Tyse Scrutiny Dev ==="

# Pull imágenes
if [ "$RESTART_ONLY" = false ]; then
    log "Descargando imágenes actualizadas..."
    if [ -n "$SERVICE" ]; then
        $COMPOSE_CMD pull "$SERVICE"
    else
        $COMPOSE_CMD pull
    fi
    ok "Imágenes descargadas"
fi

if [ "$PULL_ONLY" = true ]; then
    ok "Solo pull completado"
    exit 0
fi

# Desplegar
if [ -n "$SERVICE" ]; then
    log "Reiniciando servicio: $SERVICE"
    $COMPOSE_CMD up -d --no-deps "$SERVICE"
    ok "$SERVICE reiniciado"
else
    log "Levantando infraestructura..."
    $COMPOSE_CMD up -d consul consul-config-loader kafka minio minio-init mailhog
    ok "Infraestructura lista"

    log "Levantando bases de datos..."
    $COMPOSE_CMD up -d postgres-gateway postgres-divipol postgres-scrutiny
    ok "Bases de datos listas"

    log "Esperando health checks de BD (15s)..."
    sleep 15

    log "Levantando microservicios..."
    $COMPOSE_CMD up -d gateway divipol scrutiny mock-pipeline notification
    ok "Microservicios levantados"

    log "Levantando nginx..."
    $COMPOSE_CMD up -d nginx
    ok "Nginx listo"
fi

log ""
log "=== Health Check ==="
"$SCRIPT_DIR/health-check.sh"
