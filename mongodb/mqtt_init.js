function requireEnv(name) {
  const value = process.env[name]
  if (!value) {
    throw new Error(`${name} is required`)
  }

  return value
}

const mqttDb = db.getSiblingDB("mqtt")

const MONGO_EMQX_USER = requireEnv("MONGO_EMQX_USER")
const MONGO_EMQX_PASS = requireEnv("MONGO_EMQX_PASS")
const MONGO_HUBOT_USER = requireEnv("MONGO_HUBOT_USER")
const MONGO_HUBOT_PASS = requireEnv("MONGO_HUBOT_PASS")

function ensureCollection(name) {
  if (mqttDb.getCollectionInfos({ name: name }).length === 0) {
    mqttDb.createCollection(name)
  }
}

function ensureUser(username, password, roles) {
  if (mqttDb.getUser(username)) {
    mqttDb.updateUser(username, {
      pwd: password,
      roles: roles
    })
  } else {
    mqttDb.createUser({
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
      "uplink",
      "malla",
      "meshview",
      "yeraze"
    ],
    banned_substrings: [
      "bridge",
      "flmesh"
    ]
  }

  mqttDb.username_policy.updateOne(
    { _id: "default" },
    {
      $set: {
        ...policy,
        updated_at: now,
        updated_by: "mqtt_init.js"
      },
      $setOnInsert: {
        _id: "default",
        created_at: now,
        created_by: "mqtt_init.js"
      }
    },
    { upsert: true }
  )
}

function ensureProfile(profileDoc) {
  const now = new Date()
  mqttDb.profiles.updateOne(
    { name: profileDoc.name },
    {
      $set: {
        description: profileDoc.description,
        status: profileDoc.status,
        is_default: profileDoc.is_default,
        rules: profileDoc.rules,
        updated_at: now,
        updated_by: "mqtt_init.js"
      },
      $setOnInsert: {
        name: profileDoc.name,
        created_at: now,
        created_by: "mqtt_init.js"
      }
    },
    { upsert: true }
  )
}

function ensureDefaultProfiles() {
  /*
    {
      allow,
      {username, "${username}"},
      all,
      ["msh/US/FL/#"]
    }.
  */
  ensureProfile({
    name: "default",
    description: "Default Florida Mesh access.",
    status: "active",
    is_default: true,
    rules: [
      {
        permission: "allow",
        who: {
          username: "${username}"
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

  /*
    {
      allow,
      {username, "${username}"},
      all, 
      ["msh/US/FL/LWS/#"]
    }.
  */
  ensureProfile({
    name: "lonewolf",
    description: "Lone Wolf System with access only to the Lone Wolf subtree.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "${username}"
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

  /*
    {
      allow,
      {username, "${username}"},
      publish,
      ["msh/US/FL/#"]
    }.
    {
      allow,
      {username, "${username}"},
      publish,
      ["$SYS/broker/connection/${clientid}/#"]
    }.
  */
  ensureProfile({
    name: "bridge",
    description: "Florida Mesh Bridge profile. Allow PUBLISH to Florida subtree and $SYS broker connection topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "${username}"
        },
        action: {
          type: "publish"
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
          username: "${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "$SYS/broker/connection/${clientid}/#"
          }
        ]
      }
    ]
  })

  /*
    {
      allow,
      {username, "${username}"},
      all,
      ["msh/US/FL/#"]
    }.
    {
      allow,
      {username, "${username}"},
      publish,
      ["$SYS/broker/connection/${clientid}/#"]
    }.
  */
  ensureProfile({
    name: "fullbridge",
    description: "Florida Mesh Full Bridge profile. Allow PUB/SUB to Florida subtree and $SYS broker connection topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "${username}"
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
          username: "${username}"
        },
        action: {
          type: "all"
        },
        topics: [
          {
            match: "filter",
            value: "$SYS/broker/connection/${clientid}/#"
          }
        ]
      }
    ]
  })

  /*
    {
      allow,
      {username, "${username}"},
      all,
      ["msh/US/FL/#"]
    }.
    {
      allow,
      {
        'and',
        [
          {username, "${username}"},
          {clientid, {re, "^(meshpoint-[A-Fa-f0-9]+)$"}}
        ]
      },
      all,
      ["homeassistant/#"]
    }.
  */
  ensureProfile({
    name: "meshpoint",
    description: "Meshpoint access. Allow the broader Florida subtree and homeassistant topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "${username}"
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
          username: "${username}",
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

  /*
    {
      allow,
      {username, "${username}"},
      subscribe,
      ["$SYS/#"]
    }.
    {
      allow,
      {username, "${username}"},
      all,
      ["msh/US/FL/#"]
    }.
  */
  ensureProfile({
    name: "admin",
    description: "Florida Mesh Admin access. Allow the broader Florida subtree and subscribe to $SYS topics.",
    status: "active",
    is_default: false,
    rules: [
      {
        permission: "allow",
        who: {
          username: "${username}"
        },
        action: {
          type: "subscribe"
        },
        topics: [
          {
            match: "filter",
            value: "$SYS/#"
          }
        ]
      },
      {
        permission: "allow",
        who: {
          username: "${username}"
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

ensureCollection("users")
ensureCollection("profiles")
ensureCollection("mqtt_acl")
ensureCollection("mqtt_audit")
ensureCollection("requests")
ensureCollection("username_policy")

mqttDb.users.createIndex({ username: 1 }, { unique: true, name: "uniq_username" })
mqttDb.users.createIndex({ discord_user_id: 1 }, { unique: true, sparse: true, name: "uniq_discord_user_id" })
mqttDb.users.createIndex({ status: 1 }, { name: "idx_status" })
mqttDb.users.createIndex({ profile: 1 }, { name: "idx_profile" })

mqttDb.profiles.createIndex({ name: 1 }, { unique: true, name: "uniq_profile_name" })
mqttDb.profiles.createIndex({ is_default: 1 }, { name: "idx_profiles_is_default" })
mqttDb.profiles.createIndex({ status: 1 }, { name: "idx_profiles_status" })

mqttDb.mqtt_acl.createIndex({ username: 1 }, { name: "idx_acl_username" })
mqttDb.mqtt_acl.createIndex({ username: 1, permission: 1, action: 1 }, { name: "idx_acl_user_perm_action" })

mqttDb.mqtt_audit.createIndex({ command_id: 1, created_at: -1 }, { name: "idx_audit_command_created_at" })
mqttDb.mqtt_audit.createIndex({ "actor.discord_user_id": 1, created_at: -1 }, { name: "idx_audit_actor_created_at" })
mqttDb.mqtt_audit.createIndex({ phase: 1, created_at: -1 }, { name: "idx_audit_phase_created_at" })

mqttDb.requests.createIndex({ requested_username: 1 }, { name: "idx_requested_username" })
mqttDb.requests.createIndex({ discord_user_id: 1 }, { name: "idx_requests_discord_user_id" })
mqttDb.requests.createIndex({ status: 1, created_at: -1 }, { name: "idx_requests_status_created_at" })

mqttDb.username_policy.createIndex({ updated_at: -1 }, { name: "idx_username_policy_updated_at" })

ensureDefaultProfiles()
ensureDefaultUsernamePolicy()

ensureUser(MONGO_EMQX_USER, MONGO_EMQX_PASS, [
  { role: "read", db: "mqtt" }
])

ensureUser(MONGO_HUBOT_USER, MONGO_HUBOT_PASS, [
  { role: "readWrite", db: "mqtt" }
])

mqttDb.getUsers()
