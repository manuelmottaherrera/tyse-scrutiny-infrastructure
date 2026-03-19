#!/bin/bash

################################################################################
# Sincronización Producción → Desarrollo
#
# Descarga las BDs de producción, sanitiza datos sensibles e importa en dev.
#
# Requisitos:
#   - Acceso SSH al servidor de producción (o conexión directa a RDS)
#   - pg_dump y psql instalados
#   - Variables en .env.sync (ver .env.sync.example)
#
# Uso:
#   ./scripts/sync-prod-to-dev.sh                    # Todas las BDs
#   ./scripts/sync-prod-to-dev.sh --db gateway       # Solo gateway
#   ./scripts/sync-prod-to-dev.sh --dry-run          # Solo exportar, no importar
#
# Cron (lunes 3 AM):
#   0 3 * * 1 /home/tyse/tyse-scrutiny/dev/scripts/sync-prod-to-dev.sh >> /home/tyse/tyse-scrutiny/dev/logs/sync.log 2>&1
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$SCRIPT_DIR")"
SYNC_ENV="$DEV_DIR/.env.sync"
DUMP_DIR="$DEV_DIR/sync-dumps"
LOG_DIR="$DEV_DIR/logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
ok()  { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1"; }
warn(){ echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1"; }

# Parse argumentos
DB_FILTER=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --db) DB_FILTER="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
done

# Cargar configuración
if [ ! -f "$SYNC_ENV" ]; then
    err "No se encontró $SYNC_ENV. Copiar de .env.sync.example"
    exit 1
fi
source "$SYNC_ENV"

mkdir -p "$DUMP_DIR" "$LOG_DIR"

# ============================================================================
# Funciones de sanitización por BD
# ============================================================================

sanitize_gateway() {
    local dump_file="$1"
    log "Sanitizando BD gateway..."

    # Crear script SQL de sanitización
    cat > "$DUMP_DIR/sanitize_gateway.sql" << 'EOSQL'
-- Sanitizar usuarios
UPDATE jhi_user SET
    email = 'user' || id || '@test.tyse.local',
    password_hash = '$2a$10$gSAhZrxMllrbgj/kkK9UceBPpChGWJA7SYIb1Mqo.n5aNLq1/oRrC',
    first_name = 'Usuario',
    last_name = 'Test' || id,
    activation_key = NULL,
    reset_key = NULL,
    reset_date = NULL
WHERE login NOT IN ('admin', 'system', 'anonymoususer');

-- Mantener admin con password conocido (admin/admin)
UPDATE jhi_user SET
    password_hash = '$2a$10$gSAhZrxMllrbgj/kkK9UceBPpChGWJA7SYIb1Mqo.n5aNLq1/oRrC'
WHERE login = 'admin';
EOSQL

    ok "Gateway sanitizada"
}

sanitize_divipol() {
    local dump_file="$1"
    log "Sanitizando BD divipol..."

    cat > "$DUMP_DIR/sanitize_divipol.sql" << 'EOSQL'
-- Sanitizar testigos electorales (datos personales)
UPDATE testigo_electoral SET
    nombres = 'Testigo',
    apellidos = 'Electoral' || id,
    documento = '10000000' || id,
    telefono = '300000' || LPAD(id::text, 4, '0'),
    email = 'testigo' || id || '@test.tyse.local'
WHERE id IS NOT NULL;

-- Datos públicos: divipol, organizacion_politica, comision_escrutadora, mesa_votacion
-- NO se sanitizan (son datos públicos del estado colombiano)
EOSQL

    ok "Divipol sanitizada"
}

sanitize_scrutiny() {
    local dump_file="$1"
    log "Sanitizando BD scrutiny..."

    cat > "$DUMP_DIR/sanitize_scrutiny.sql" << 'EOSQL'
-- Datos E14, anomalías, preconteo: datos públicos electorales
-- NO se sanitizan

-- Sanitizar processed_document si tiene paths con info sensible
-- (por ahora no hay datos personales en esta BD)
EOSQL

    ok "Scrutiny sanitizada (solo datos públicos)"
}

# ============================================================================
# Exportar BD de producción
# ============================================================================

export_db() {
    local db_name="$1"
    local dump_file="$DUMP_DIR/${db_name}_${TIMESTAMP}.sql"

    log "Exportando $db_name desde producción..."

    PGPASSWORD="$PROD_DB_PASSWORD" pg_dump \
        -h "$PROD_DB_HOST" \
        -p "$PROD_DB_PORT" \
        -U "$PROD_DB_USER" \
        -d "$db_name" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        -f "$dump_file"

    ok "Exportado: $dump_file ($(du -h "$dump_file" | cut -f1))"
    echo "$dump_file"
}

# ============================================================================
# Importar BD en desarrollo
# ============================================================================

import_db() {
    local db_name="$1"
    local dump_file="$2"
    local sanitize_file="$3"
    local container="$4"

    log "Importando $db_name en dev..."

    # Copiar dump al contenedor
    docker cp "$dump_file" "$container:/tmp/dump.sql"

    # Importar
    docker exec "$container" sh -c \
        "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/dump.sql" \
        > "$LOG_DIR/import_${db_name}_${TIMESTAMP}.log" 2>&1

    # Sanitizar
    if [ -f "$sanitize_file" ]; then
        docker cp "$sanitize_file" "$container:/tmp/sanitize.sql"
        docker exec "$container" sh -c \
            "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/sanitize.sql" \
            > "$LOG_DIR/sanitize_${db_name}_${TIMESTAMP}.log" 2>&1
    fi

    # Limpiar
    docker exec "$container" rm -f /tmp/dump.sql /tmp/sanitize.sql

    ok "$db_name importada y sanitizada"
}

# ============================================================================
# Proceso principal
# ============================================================================

log "=== Sync Producción → Desarrollo ==="
log "Timestamp: $TIMESTAMP"
[ "$DRY_RUN" = true ] && warn "MODO DRY-RUN: solo exportar, no importar"

# Bases de datos a sincronizar
declare -A DBS
DBS[gateway]="tyse-pg-gateway-dev"
DBS[divipol]="tyse-pg-divipol-dev"
DBS[scrutiny]="tyse-pg-scrutiny-dev"

# Nombres de BD en producción (pueden diferir)
declare -A PROD_DB_NAMES
PROD_DB_NAMES[gateway]="${PROD_GATEWAY_DB_NAME:-tysescrutinygateway}"
PROD_DB_NAMES[divipol]="${PROD_DIVIPOL_DB_NAME:-tysescrutinymicrodivipol}"
PROD_DB_NAMES[scrutiny]="${PROD_SCRUTINY_DB_NAME:-tyseScrutinyMicroScrutiny}"

for db in "${!DBS[@]}"; do
    # Filtrar si se especificó una BD
    if [ -n "$DB_FILTER" ] && [ "$db" != "$DB_FILTER" ]; then
        continue
    fi

    container="${DBS[$db]}"
    prod_db_name="${PROD_DB_NAMES[$db]}"

    log "--- Procesando: $db ---"

    # 1. Exportar
    dump_file=$(export_db "$prod_db_name")

    # 2. Generar script de sanitización
    "sanitize_${db}" "$dump_file"
    sanitize_file="$DUMP_DIR/sanitize_${db}.sql"

    # 3. Importar (si no es dry-run)
    if [ "$DRY_RUN" = false ]; then
        import_db "$db" "$dump_file" "$sanitize_file" "$container"
    fi

    echo ""
done

# Limpiar dumps antiguos (mantener últimos 3)
log "Limpiando dumps antiguos..."
ls -t "$DUMP_DIR"/*.sql 2>/dev/null | tail -n +10 | xargs -r rm
ok "Limpieza completada"

log ""
ok "=== Sincronización completada ==="
log "Logs en: $LOG_DIR"
log "Dumps en: $DUMP_DIR"
