#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[ERROR] .env file not found at ${ENV_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

BACKUP_BASE="${BACKUP_DIR:-${ROOT_DIR}/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Resolve relative backup path from repository root.
if [[ "${BACKUP_BASE}" != /* ]]; then
  BACKUP_BASE="${ROOT_DIR}/${BACKUP_BASE#./}"
fi

TARGET_DIR="${BACKUP_BASE}/${TIMESTAMP}"

mkdir -p "${TARGET_DIR}"

echo "[INFO] Creating backup at ${TARGET_DIR}"

# PostgreSQL dump
PG_DUMP_FILE="${TARGET_DIR}/postgres.sql.gz"
docker compose -f "${ROOT_DIR}/docker-compose.yml" exec -T postgres \
  pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | gzip > "${PG_DUMP_FILE}"

echo "[INFO] PostgreSQL backup completed: ${PG_DUMP_FILE}"

# Readeck application data volume archive
READECK_VOLUME_ARCHIVE="${TARGET_DIR}/readeck_data.tar.gz"
docker run --rm \
  -v readeck_data:/data:ro \
  -v "${TARGET_DIR}:/backup" \
  alpine:3.20 \
  sh -c "tar -czf /backup/readeck_data.tar.gz -C /data ."

echo "[INFO] Readeck data backup completed: ${READECK_VOLUME_ARCHIVE}"

# Metadata
cat > "${TARGET_DIR}/backup-meta.txt" <<EOF
timestamp=${TIMESTAMP}
postgres_db=${POSTGRES_DB}
postgres_user=${POSTGRES_USER}
host=$(hostname)
EOF

# Retention policy
find "${BACKUP_BASE}" -mindepth 1 -maxdepth 1 -type d -mtime +"${RETENTION_DAYS}" -exec rm -rf {} +

echo "[INFO] Backup completed successfully"

