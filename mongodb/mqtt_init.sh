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

function ensureDefaultUsernamePolicy() {
  const now = new Date()
  const policy = {
    pattern: "^[a-z][a-z0-9_-]{2,23}$",
    min_length: 3,
    max_length: 24,
    reserved_usernames: [
      "admin",
      "root",
      "system",
      "emqx",
      "hubot",
      "floodgate",
      "uplink"
    ],
    banned_substrings: [
      "bridge",
      "bridge_"
    ]
  }

  db.username_policy.updateOne(
    { _id: "default" },
    {
      \$set: {
        ...policy,
        updated_at: now,
        updated_by: "mqtt_init.sh"
      },
      \$setOnInsert: {
        _id: "default",
        created_at: now,
        created_by: "mqtt_init.sh"
      }
    },
    { upsert: true }
  )
}

function ensureProfile(profileDoc) {
  const now = new Date()
  db.profiles.updateOne(
    { name: profileDoc.name },
    {
      \$set: {
        description: profileDoc.description,
        status: profileDoc.status,
        is_default: profileDoc.is_default,
        rules: profileDoc.rules,
        updated_at: now,
        updated_by: "mqtt_init.sh"
      },
      \$setOnInsert: {
        name: profileDoc.name,
        created_at: now,
        created_by: "mqtt_init.sh"
      }
    },
    { upsert: true }
  )
}

function ensureDefaultProfiles() {
  // {deny, {username, "\${username}"}, all, ["msh/US/FL/LWS/#"]}.
  // {allow, {username, "\${username}"}, all, ["msh/US/FL/#"]}.
  ensureProfile({
    name: "default",
    description: "Default Florida Mesh access. Deny Lone Wolf subtree and allow the broader Florida subtree.",
    status: "active",
    is_default: true,
    rules: [
      {
        permission: "deny",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/LWS/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/#"
          }
        ]
      }
    ]
  })

  // {allow, {username, "\${username}"}, all, ["msh/US/FL/LWS/#"]}.
  ensureProfile({
    name: "lonewolf",
    description: "Lone Wolf profile with access only to the Lone Wolf subtree.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/LWS/#"
          }
        ]
      }
    ]
  })

  // {deny, {username, "\${username}"}, all, ["msh/US/FL/LWS/#"]}.
  // {allow, {username, "\${username}"}, all, ["msh/US/FL/#"]}.
  // {allow, {username, "\${username}"}, publish, ["\$SYS/broker/connection/\${clientid}/state"]}.
  ensureProfile({
    name: "bridge",
    description: "MQTT Bridge access. Deny Lone Wolf subtree and allow the broader Florida subtree and \$SYS/broker topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "deny",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/LWS/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "publish"
        },
        topics: [
          {
            match: "filter",
            value: "\$SYS/broker/connection/\${clientid}/state"
          }
        ]
      }
    ]
  })

  // {deny, {username, "\${username}"}, all, ["msh/US/FL/LWS/#"]}.
  // {allow, {username, "\${username}"}, all, ["msh/US/FL/#"]}.
  // {allow, {'and', [{username, "\${username}"}, {clientid, {re, "^(meshpoint-[A-Fa-f0-9]+)$"}}]}, all, ["homeassistant/#"]}.
  ensureProfile({
    name: "meshpoint",
    description: "MQTT Meshpoint access. Deny Lone Wolf subtree and allow the broader Florida subtree and homeassistant topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "deny",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/LWS/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "\${username}",
          clientid_re: "^(meshpoint-[A-Fa-f0-9]+)$"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "homeassistant/#"
          }
        ]
      }
    ]
  })

  // {allow, {username, "\${username}"}, subscribe, ["\$SYS/#"]}.
  // {allow, {username, "\${username}"}, all, ["msh/US/FL/#"]}.
  ensureProfile({
    name: "admin",
    description: "Allow admin users to subscribe to \$SYS topics and publish+subscribe to FL mesh topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "subscribe"
        },
        topics: [
          {
            match: "filter",
            value: "\$SYS/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "\${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "msh/US/FL/#"
          }
        ]
      }
    ]
  })
}

// Create collections explicitly if they do not already exist
ensureCollection("users")
ensureCollection("profiles")
ensureCollection("mqtt_acl")
ensureCollection("mqtt_audit")
ensureCollection("requests")
ensureCollection("username_policy")

// Indexes for EMQX lookups and admin/Hubot searches
db.users.createIndex({ username: 1 }, { unique: true, name: "uniq_username" })
db.users.createIndex({ discord_user_id: 1 }, { unique: true, sparse: true, name: "uniq_discord_user_id" })
db.users.createIndex({ status: 1 }, { name: "idx_status" })
db.users.createIndex({ profile: 1 }, { name: "idx_profile" })

db.profiles.createIndex({ name: 1 }, { unique: true, name: "uniq_profile_name" })
db.profiles.createIndex({ is_default: 1 }, { name: "idx_profiles_is_default" })
db.profiles.createIndex({ status: 1 }, { name: "idx_profiles_status" })

db.mqtt_acl.createIndex({ username: 1 }, { name: "idx_acl_username" })
db.mqtt_acl.createIndex({ username: 1, permission: 1, action: 1 }, { name: "idx_acl_user_perm_action" })

db.mqtt_audit.createIndex({ command_id: 1, created_at: -1 }, { name: "idx_audit_command_created_at" })
db.mqtt_audit.createIndex({ "actor.discord_user_id": 1, created_at: -1 }, { name: "idx_audit_actor_created_at" })
db.mqtt_audit.createIndex({ phase: 1, created_at: -1 }, { name: "idx_audit_phase_created_at" })

db.requests.createIndex({ requested_username: 1 }, { name: "idx_requested_username" })
db.requests.createIndex({ discord_user_id: 1 }, { name: "idx_requests_discord_user_id" })
db.requests.createIndex({ status: 1, created_at: -1 }, { name: "idx_requests_status_created_at" })

db.username_policy.createIndex({ updated_at: -1 }, { name: "idx_username_policy_updated_at" })

// Seed default profile definitions
ensureDefaultProfiles()

// Seed default username validation policy if it does not already exist
ensureDefaultUsernamePolicy()

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
