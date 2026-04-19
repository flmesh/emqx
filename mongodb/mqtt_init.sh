#!/usr/bin/env bash
set -euo pipefail

MONGO_ROOT_USER="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_USERNAME)"
MONGO_ROOT_PASS="$(docker compose exec mongodb printenv MONGO_INITDB_ROOT_PASSWORD)"
MONGO_EMQX_USER="$(docker compose exec mongodb printenv MONGO_EMQX_USER)"
MONGO_EMQX_PASS="$(docker compose exec mongodb printenv MONGO_EMQX_PASS)"
MONGO_HUBOT_USER="$(docker compose exec mongodb printenv MONGO_HUBOT_USER)"
MONGO_HUBOT_PASS="$(docker compose exec mongodb printenv MONGO_HUBOT_PASS)"

mongo_root_exec() {
  docker compose exec -T mongodb mongosh \
    --username "$MONGO_ROOT_USER" \
    --password "$MONGO_ROOT_PASS" \
    --authenticationDatabase admin "$@"
}

mongo_root_exec <<EOF
use mqtt

function ensureCollection(name) {
  if (db.getCollectionInfos({ name: name }).length === 0) {
    db.createCollection(name)
  }
}

function ensureUser(username, password, roles) {
  if (db.getUser(username)) {
    db.updateUser(username, {
      pwd: password,
      roles: roles
    })
  } else {
    db.createUser({
      user: username,
      pwd: password,
      roles: roles
    })
  }
}

// Create collections explicitly if they do not already exist
ensureCollection("users")
ensureCollection("mqtt_acl")
ensureCollection("requests")

// Indexes for EMQX lookups and admin/Hubot searches
db.users.createIndex({ username: 1 }, { unique: true, name: "uniq_username" })
db.users.createIndex({ discord_user_id: 1 }, { unique: true, sparse: true, name: "uniq_discord_user_id" })
db.users.createIndex({ status: 1 }, { name: "idx_status" })
db.users.createIndex({ profile: 1 }, { name: "idx_profile" })

db.mqtt_acl.createIndex({ username: 1 }, { name: "idx_acl_username" })
db.mqtt_acl.createIndex({ username: 1, permission: 1, action: 1 }, { name: "idx_acl_user_perm_action" })

db.requests.createIndex({ requested_username: 1 }, { name: "idx_requested_username" })
db.requests.createIndex({ discord_user_id: 1 }, { name: "idx_requests_discord_user_id" })
db.requests.createIndex({ status: 1, created_at: -1 }, { name: "idx_requests_status_created_at" })

// Read-only user for EMQX
ensureUser("$MONGO_EMQX_USER", "$MONGO_EMQX_PASS", [
  { role: "read", db: "mqtt" }
])

// Read-write user for Hubot
ensureUser("$MONGO_HUBOT_USER", "$MONGO_HUBOT_PASS", [
  { role: "readWrite", db: "mqtt" }
])

// Optional sanity check
db.getUsers()
EOF
