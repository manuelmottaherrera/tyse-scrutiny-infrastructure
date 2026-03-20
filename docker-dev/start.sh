#!/bin/bash

################################################################################
# Arranca el entorno de desarrollo 100% Dockerizado
#
# Uso:
#   ./start.sh              # Todo el ecosistema
#   ./start.sh gateway      # Solo gateway (backend + frontend) + dependencias
#   ./start.sh divipol      # Solo divipol + dependencias
#   ./start.sh scrutiny     # Solo scrutiny + dependencias
#   ./start.sh notification # Solo notification + dependencias
#   ./start.sh infra        # Solo infraestructura (Consul, Kafka, MinIO, MailHog, BDs)
#
# Primera ejecución: ~10-15 min (descarga imágenes + dependencias Maven/npm)
# Siguientes ejecuciones: ~1-2 min (cache de Maven y npm en volumes Docker)
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.docker-dev.yml"
COMPOSE_CMD="docker compose -f $COMPOSE_FILE"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Tyse Scrutiny - Docker Dev ===${NC}"

case "${1:-all}" in
  infra)
    echo "Arrancando solo infraestructura..."
    $COMPOSE_CMD up -d consul consul-config-loader kafka minio minio-init mailhog \
      postgres-gateway postgres-divipol postgres-scrutiny
    ;;
  gateway)
    echo "Arrancando gateway + dependencias..."
    $COMPOSE_CMD up --build gateway-backend gateway-frontend
    ;;
  divipol)
    echo "Arrancando divipol + dependencias..."
    $COMPOSE_CMD up --build divipol
    ;;
  scrutiny)
    echo "Arrancando scrutiny + dependencias..."
    $COMPOSE_CMD up --build scrutiny
    ;;
  notification)
    echo "Arrancando notification + dependencias..."
    $COMPOSE_CMD up --build notification
    ;;
  all)
    echo "Arrancando TODO el ecosistema..."
    echo ""
    echo "Primera vez tarda ~10-15 min (descarga dependencias)."
    echo "Siguientes veces: ~1-2 min."
    echo ""
    $COMPOSE_CMD up --build
    ;;
  *)
    echo "Uso: ./start.sh [gateway|divipol|scrutiny|notification|infra|all]"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}Servicios disponibles:${NC}"
echo "  Frontend:  http://localhost:9000"
echo "  API:       http://localhost:8080"
echo "  Consul:    http://localhost:8500"
echo "  MinIO:     http://localhost:9001 (tyseadmin/tyseadmin123)"
echo "  MailHog:   http://localhost:8025"
