# Florida Mesh EMQX

This repository contains the Docker Compose deployment and runtime configuration for the Florida Mesh MQTT broker at `mqtt.areyoumeshingwith.us`.

Florida Mesh is available at https://areyoumeshingwith.us.

It includes:

- EMQX `6.1.1`
- persistent named volumes for EMQX data and logs
- a local `emqx.conf` override
- a Floodgate sidecar with its own config
- a helper script to register the Floodgate ExHook
- a GitHub Actions workflow that validates the stack end to end

## Services

### `emqx`

The broker is started from [`docker-compose.yml`](/home/jbouse/Git/emqx/docker-compose.yml) with:

- MQTT on `1883`
- MQTT over TLS on `8883`
- WebSocket on `8083`
- WebSocket over TLS on `8084`
- dashboard bound to `127.0.0.1:18083`

EMQX persists state in named volumes:

- `emqx-data`
- `emqx-logs`

Configuration is mounted from [`emqx.conf`](/home/jbouse/Git/emqx/emqx.conf).

### `floodgate`

Floodgate is started alongside EMQX and is configured from [`floodgate-config.yaml`](/home/jbouse/Git/emqx/floodgate-config.yaml).

Current behavior includes:

- gRPC listener on `9000`
- health endpoint on `8080`
- topic filter `msh/#`
- blacklist-based channel policy

## Configuration

Runtime environment is provided through `.env`. For local testing, this repo includes [`.env.test`](/home/jbouse/Git/emqx/.env.test) and the CI workflow symlinks it to `.env`.

Expected variables:

- `EMQX_DEFAULT_LOG_HANDLER`
- `EMQX_HOST`
- `EMQX_DASHBOARD__DEFAULT_PASSWORD`
- `CERT_PEM_PATH`
- `KEY_PEM_PATH`

TLS certificate and key files are mounted into the EMQX container from the host paths referenced by `CERT_PEM_PATH` and `KEY_PEM_PATH`.

## Local Bring-Up

1. Create or link `.env`.
2. Ensure certificate and key files exist at the paths configured in `.env`.
3. Start the stack:

```sh
docker compose up -d
```

4. Confirm status:

```sh
docker compose ps
docker compose logs --no-color
```

5. Register the Floodgate ExHook:

```sh
bash ./register-exhook.sh
```

The registration script deletes any existing `floodgate` ExHook and recreates it in a disabled state. Enable it in the EMQX dashboard when ready.

## Test Certificate Example

For local validation, a short-lived self-signed server certificate can be created with:

```sh
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout key.pem -out cert.pem \
  -days 1 \
  -subj "/CN=${EMQX_HOST}" \
  -addext "subjectAltName=DNS:${EMQX_HOST},DNS:localhost,IP:127.0.0.1" \
  -addext "basicConstraints=CA:FALSE" \
  -addext "keyUsage=digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth"

chmod 0600 key.pem
```

## CI Validation

GitHub Actions validates this repo through [`compose-validate.yml`](/home/jbouse/Git/emqx/.github/workflows/compose-validate.yml).

The workflow:

- links `.env.test` to `.env`
- generates a temporary TLS cert and key using `EMQX_HOST`
- adjusts ownership and permissions for the EMQX container user
- runs `docker compose config`
- runs `docker compose up -d`
- waits for `emqx` and `floodgate` to become healthy
- runs [`register-exhook.sh`](/home/jbouse/Git/emqx/register-exhook.sh)
- prints logs on failure
- tears the stack down

It runs on pull requests and on pushes to `main`.

## Maintainers

This repository is maintained by members of the Florida Mesh Admin team:

- [@jbouse](https://github.com/jbouse)
- [@eric-becker](https://github.com/eric-becker)

## Repository Files

- [`docker-compose.yml`](/home/jbouse/Git/emqx/docker-compose.yml): main deployment definition
- [`emqx.conf`](/home/jbouse/Git/emqx/emqx.conf): EMQX configuration overrides
- [`floodgate-config.yaml`](/home/jbouse/Git/emqx/floodgate-config.yaml): Floodgate runtime config
- [`register-exhook.sh`](/home/jbouse/Git/emqx/register-exhook.sh): ExHook registration helper
- [`.github/workflows/compose-validate.yml`](/home/jbouse/Git/emqx/.github/workflows/compose-validate.yml): CI validation workflow
- [`.github/CODEOWNERS`](/home/jbouse/Git/emqx/.github/CODEOWNERS): default code owners
