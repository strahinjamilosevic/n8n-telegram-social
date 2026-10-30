#!/usr/bin/env bash
# Archive the n8n volume. Keeps 7 days.
# n8n is paused (not stopped) for the few seconds the archive takes,
# so the SQLite file is captured in a consistent state.
# Cron (as deploy, via `crontab -e`):
#   0 3 * * * /home/deploy/n8n-telegram-social/scripts/backup.sh >> /home/deploy/backups/backup.log 2>&1
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/home/deploy/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"
cd "$PROJECT_DIR"

unpause() { docker compose unpause n8n >/dev/null 2>&1 || true; }
trap unpause EXIT

echo "$(date -Is) backup start"
docker compose pause n8n

docker run --rm \
  -v n8n_data:/source:ro \
  -v "$BACKUP_DIR":/backup \
  alpine:3.22 \
  tar czf "/backup/n8n_data-${STAMP}.tar.gz" -C /source .

unpause
trap - EXIT

find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$((RETENTION_DAYS - 1))" -delete
echo "$(date -Is) backup done: ${STAMP}"
