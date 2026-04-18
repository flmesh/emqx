#!/usr/bin/env bash

# Execute this script and tee the output to .env to generate strong 
# passwords for MongoDB users and set the root username

# 1) Set the root username and the EMQX/Hubot usernames
echo "MONGO_INITDB_ROOT_USERNAME=admin"
echo "MONGO_EMQX_USER=emqx_ro"
echo "MONGO_HUBOT_USER=hubot_rw"
# 2) Generate strong passwords for the root user and the EMQX/Hubot users
echo "MONGO_INITDB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')"
echo "MONGO_EMQX_PASS=$(openssl rand -base64 24 | tr -d '\n')"
echo "MONGO_HUBOT_PASS=$(openssl rand -base64 24 | tr -d '\n')"
