#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SCRIPT="${ROOT_DIR}/scripts/backup.sh"

echo "[INFO] Starting Readeck update workflow"

if [[ -x "${BACKUP_SCRIPT}" ]]; then
  echo "[INFO] Running pre-update backup"
  "${BACKUP_SCRIPT}"
else
  echo "[WARN] Backup script not executable; skipping pre-update backup"
fi

echo "[INFO] Pulling latest images"
docker compose -f "${ROOT_DIR}/docker-compose.yml" pull

echo "[INFO] Recreating containers"
docker compose -f "${ROOT_DIR}/docker-compose.yml" up -d --remove-orphans

echo "[INFO] Cleaning old images"
docker image prune -f

echo "[INFO] Update completed successfully"
docker compose -f "${ROOT_DIR}/docker-compose.yml" ps
