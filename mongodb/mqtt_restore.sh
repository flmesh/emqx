#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:-}"

if [[ -z "$ARCHIVE" ]]; then
  echo "Usage: $0 <backup-archive.gz>" >&2
  exit 1
fi

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Error: backup archive not found: ${ARCHIVE}" >&2
  exit 1
fi

MONGO_ROOT_USER="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_USERNAME)"
MONGO_ROOT_PASS="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_PASSWORD)"

echo "Restoring mqtt database from ${ARCHIVE} ..."
echo "WARNING: existing collections in the archive will be dropped before restore (--drop)"

docker compose exec -T mongodb mongorestore \
  --username "$MONGO_ROOT_USER" \
  --password "$MONGO_ROOT_PASS" \
  --authenticationDatabase admin \
  --db mqtt \
  --archive \
  --gzip \
  --drop < "$ARCHIVE"

echo "Restore complete."
