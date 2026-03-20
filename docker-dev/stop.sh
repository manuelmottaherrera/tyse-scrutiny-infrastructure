#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Parando todos los servicios..."
docker compose -f "$SCRIPT_DIR/docker-compose.docker-dev.yml" down

echo ""
echo "Para eliminar también los datos (BDs, cache Maven, etc.):"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.docker-dev.yml down -v"
