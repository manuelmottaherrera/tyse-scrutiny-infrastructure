#!/bin/bash

################################################################################
# Health Check - Tyse Scrutiny Dev
#
# Verifica el estado de todos los servicios del ecosistema.
################################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$DEV_DIR/docker-compose.dev.yml"
ENV_FILE="$DEV_DIR/.env.dev"

COMPOSE_CMD="docker compose -f $COMPOSE_FILE --env-file $ENV_FILE"

check_container() {
    local name="$1"
    local status
    status=$($COMPOSE_CMD ps --format '{{.Status}}' "$name" 2>/dev/null | head -1)

    if echo "$status" | grep -q "(healthy)"; then
        echo -e "  ${GREEN}✓${NC} $name: healthy"
    elif echo "$status" | grep -q "Up"; then
        echo -e "  ${YELLOW}~${NC} $name: running (no healthcheck)"
    else
        echo -e "  ${RED}✗${NC} $name: $status"
    fi
}

check_url() {
    local name="$1"
    local url="$2"
    if curl -sf --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name: $url"
    else
        echo -e "  ${RED}✗${NC} $name: $url (no responde)"
    fi
}

echo ""
echo "--- Contenedores ---"
for svc in consul kafka minio mailhog postgres-gateway postgres-divipol postgres-scrutiny gateway divipol scrutiny mock-pipeline notification nginx; do
    check_container "$svc"
done

echo ""
echo "--- Endpoints ---"
check_url "Nginx (gateway)" "http://localhost:80"
check_url "Consul UI" "http://localhost:8510"
check_url "MinIO UI" "http://localhost:9001"
check_url "MailHog UI" "http://localhost:8035"
echo ""
