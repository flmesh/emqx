#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${1:-${SCRIPT_DIR}/backups}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="${BACKUP_DIR}/mqtt_${TIMESTAMP}.gz"

# profiles and username_policy are omitted — mqtt_init.js recreates them on restore
COLLECTIONS=(users mqtt_acl mqtt_audit requests)

MONGO_ROOT_USER="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_USERNAME)"
MONGO_ROOT_PASS="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_PASSWORD)"

mkdir -p "$BACKUP_DIR"

echo "Backing up mqtt collections (${COLLECTIONS[*]}) to ${ARCHIVE} ..."

docker compose exec -T mongodb mongodump \
  --username "$MONGO_ROOT_USER" \
  --password "$MONGO_ROOT_PASS" \
  --authenticationDatabase admin \
  --db mqtt \
  $(printf -- '--collection %s ' "${COLLECTIONS[@]}") \
  --archive \
  --gzip > "$ARCHIVE"

echo "Backup complete: ${ARCHIVE}"
