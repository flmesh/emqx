#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MONGO_ROOT_USER="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_USERNAME)"
MONGO_ROOT_PASS="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_PASSWORD)"

mongo_root_exec() {
  docker compose exec -T mongodb mongosh \
    --username "$MONGO_ROOT_USER" \
    --password "$MONGO_ROOT_PASS" \
    --authenticationDatabase admin "$@"
}

# Keep the MongoDB defaults in the JS initializer so Docker can also run them
# automatically from /docker-entrypoint-initdb.d on a fresh database.
mongo_root_exec < "$SCRIPT_DIR/mqtt_init.js"
