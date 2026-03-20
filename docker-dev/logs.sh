#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="${1:-gateway-backend}"

echo "Mostrando logs de: $SERVICE"
echo "  (Ctrl+C para salir)"
echo ""
docker compose -f "$SCRIPT_DIR/docker-compose.docker-dev.yml" logs -f "$SERVICE"
