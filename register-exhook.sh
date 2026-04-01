#!/usr/bin/env bash
# Register floodgate ExHook with EMQX. Run once after first deploy.
# Reads EMQX_DASHBOARD__DEFAULT_PASSWORD from .env
set -euo pipefail

[ -f .env ] && source .env

TOKEN=$(curl -sf -X POST http://localhost:18083/api/v5/login \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"${EMQX_DASHBOARD__DEFAULT_PASSWORD}\"}" | jq -r .token)

# Remove existing registration if present
curl -sf -X DELETE http://localhost:18083/api/v5/exhooks/floodgate \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null || true

curl -sf -X POST http://localhost:18083/api/v5/exhooks \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "floodgate",
    "url": "http://floodgate:9000",
    "auto_reconnect": "60s",
    "failed_action": "ignore",
    "enable": false
  }'

echo "floodgate ExHook registered (disabled). Enable in EMQX dashboard when ready."
