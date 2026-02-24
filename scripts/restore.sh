#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-directory>"
  echo "Example: $0 backups/20260224-033000"
  exit 1
fi

BACKUP_PATH="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ "${BACKUP_PATH}" != /* ]]; then
  BACKUP_PATH="${ROOT_DIR}/${BACKUP_PATH#./}"
fi

if [[ ! -d "${BACKUP_PATH}" ]]; then
  echo "[ERROR] Backup directory not found: ${BACKUP_PATH}"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[ERROR] .env file not found at ${ENV_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

PG_DUMP_FILE="${BACKUP_PATH}/postgres.sql.gz"
READECK_ARCHIVE="${BACKUP_PATH}/readeck_data.tar.gz"

if [[ ! -f "${PG_DUMP_FILE}" ]]; then
  echo "[ERROR] Missing PostgreSQL dump: ${PG_DUMP_FILE}"
  exit 1
fi

if [[ ! -f "${READECK_ARCHIVE}" ]]; then
  echo "[ERROR] Missing Readeck data archive: ${READECK_ARCHIVE}"
  exit 1
fi

echo "[WARN] This operation will overwrite current database and app data."
read -r -p "Type 'RESTORE' to continue: " confirm

if [[ "${confirm}" != "RESTORE" ]]; then
  echo "[INFO] Restore cancelled"
  exit 0
fi

echo "[INFO] Stopping Readeck service"
docker compose -f "${ROOT_DIR}/docker-compose.yml" stop readeck

echo "[INFO] Restoring PostgreSQL database"
gunzip -c "${PG_DUMP_FILE}" | docker compose -f "${ROOT_DIR}/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"

echo "[INFO] Restoring Readeck data volume"
docker run --rm \
  -v readeck_data:/data \
  -v "$(cd "${BACKUP_PATH}" && pwd):/backup:ro" \
  alpine:3.20 \
  sh -c "rm -rf /data/* && tar -xzf /backup/readeck_data.tar.gz -C /data"

echo "[INFO] Starting services"
docker compose -f "${ROOT_DIR}/docker-compose.yml" up -d

echo "[INFO] Restore completed successfully"

