# bytEM Installation Guide

<sub>Alpha · Ubuntu 24.04 · Docker deployment</sub>

**Install and configure a self-hosted bytEM instance.**

> [!NOTE]
> This guide covers the standard Docker-based bytEM installation on Ubuntu 24.04.

> [!IMPORTANT]
> Throughout this guide, replace:
>
> - `your-domain` with your actual domain or subdomain
> - `<USERNAME>` with your Matrix/bytEM username
> - `<PASSWORD>` with a strong password

## Installation Flow

```text
Prepare Server
     │
     ▼
Configure Environment
     │
     ▼
Install bytEM
     │
     ▼
Verify Containers
     │
     ▼
Configure HTTPS
     │
     ▼
Join bytEM Network
     │
     ▼
Create Administrator
     │
     ▼
Verify Installation
```

### Quick Install

After Docker is installed and the repository has been cloned, the main installation sequence is:

```bash
sudo ./env_setup.sh
sudo ./install.sh
sudo ./certbot.sh
sudo ./whitelist-sync.sh
```

> [!TIP]
> **Video installation guide:**  
> https://github.com/user-attachments/assets/73e70afb-fae8-460c-9ce4-6636fe058f05

## Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Verify Installation](#verify-installation)
- [Upgrade bytEM](#upgrade-bytem)
- [Appendix — Deployment Architecture](#appendix--deployment-architecture)
- [Troubleshooting](#troubleshooting)
- [Support](#support)
- [bytEM User Guide](#bytem-user-guide)

## Prerequisites

Before installation, make sure the server meets the following requirements.

| Requirement | Minimum / Details |
|---|---|
| **Operating system** | Ubuntu 24.04 |
| **CPU** | 2 cores |
| **Memory** | 8 GB RAM |
| **Storage** | 80 GB |
| **Network** | Public IP address |
| **DNS** | Dedicated domain or subdomain |
| **Credentials** | Custom credentials for the bot user, RabbitMQ, Synapse, and related services |

> [!IMPORTANT]
> Before running `certbot.sh`, ensure the bytEM and Matrix hostnames resolve to this server's public IP address.

## Installation

### 1. Install Docker and Clone bytEM

Install Docker, Docker Compose, Git, and clone the repository:

```bash
sudo apt update
sudo apt install docker docker-compose git

git clone https://github.com/liberbyte/bytEM-public.git
cd bytEM-public
```

> [!TIP]
> If `docker-compose` is not recognized, create the compatibility symlink:
>
> ```bash
> sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
> ```

> [!NOTE]
> If `git clone` fails with a permission error, use `sudo git clone ...` instead.

#### Optional — Move Docker Storage

If the server has a dedicated storage volume, for example `/xxx-liberbyte`, Docker's data directory can be moved to avoid filling the root filesystem.

> [!IMPORTANT]
> Perform this step **before running any other bytEM installation scripts**.

```bash
# Stop Docker
sudo systemctl stop docker

# Create directory on dedicated storage
sudo mkdir -p /xxx-liberbyte/bytem/docker

# Move Docker data
sudo mv /var/lib/docker /xxx-liberbyte/bytem/docker

# Create symlink
sudo ln -s /xxx-liberbyte/bytem/docker /var/lib/docker

# Restart Docker
sudo systemctl start docker

# Verify the new location
sudo docker info | grep "Docker Root Dir"
# Expected: Docker Root Dir: /xxx-liberbyte/bytem/docker

# Navigate to dedicated storage
cd /xxx-liberbyte
```

**Result:** Docker images, containers, and volumes are stored on the larger dedicated volume, keeping the root filesystem clear. No changes to the bytEM installation scripts are required afterward.

### 2. Configure the Environment

Run `env_setup.sh` before the installer:

```bash
sudo ./env_setup.sh
```

When prompted, enter:

- Your subdomain, for example `liberbyte.app`
- Your prefix, for example `bm4`
- Custom credentials for the bot user, RabbitMQ, Synapse, and related services

#### Result

`env_setup.sh`:

- creates `generated_config_files/`
- creates:
  - `generated_config_files/nginx_config/`
  - `generated_config_files/synapse_config/`
- populates configuration files from templates in `config_templates/`
- generates `.env.bytem` from `.env.template`
- prompts you to back up an existing `.env.bytem` before overwriting it

### 3. Install bytEM

Run:

```bash
sudo ./install.sh
```

#### Result

`install.sh`:

- sets ownership on `generated_config_files/` so the Synapse container can read it
- pulls Docker images and starts all containers via `docker-compose.yaml`
- registers the bot/admin Matrix user and saves the login token to `.env.bytem`
- restarts the stack so all containers use the new token
- patches hardcoded domains in the frontend bundle to match the configured domain
- creates a welcome page for the Matrix subdomain
- configures internal networking so the app can reach the homeserver

> [!NOTE]
> If you see **Cannot reach homeserver** after restarting or upgrading, rerun:
>
> ```bash
> sudo ./install.sh
> ```

### 4. Verify Containers

After `install.sh` completes:

```bash
sudo docker ps
```

All bytEM containers should show a status of `Up`.

### 5. Configure HTTPS

Run:

```bash
sudo ./certbot.sh
```

Enter an email address when prompted. It is used for Let's Encrypt renewal notices.

#### Result

`certbot.sh`:

- bootstraps a temporary self-signed certificate so Nginx can start immediately
- obtains or renews Let's Encrypt SSL certificates for bytEM and Matrix domains
- falls back to the self-signed certificate if Let's Encrypt is unavailable
- regenerates Nginx configuration with the correct certificate paths
- reloads Nginx
- patches hardcoded domains in the frontend bundle

### 6. Synchronize the Federation Whitelist

bytEM uses a whitelist to control which servers can communicate with the instance. Only approved servers can exchange data with it.

This provides:

- **Security** — prevents unauthorized servers from accessing the data catalog
- **Trust** — connects the instance only with verified bytEM peers
- **Federation control** — defines the trusted peer network

Run:

```bash
sudo ./whitelist-sync.sh
```

#### Result

`whitelist-sync.sh`:

- fetches the latest allowed-domain list from the bytEM registry
- updates `homeserver.yaml` with the federation whitelist
- restricts the `/solr` endpoint in Nginx to bytEM servers only
- reloads Nginx and Matrix Synapse configuration inside their containers
- sets the bot/admin user's Matrix rate-limit override so it is not throttled by Synapse
- restarts `bytem-synapse`, `bytem-bot`, `bytem-be`, and `bytem-app`

### 7. Create the First Administrator

A Matrix user is required to log in and verify the installation.

#### Interactive Method

```bash
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  http://localhost:8008
```

Enter:

- username
- password
- whether the user should receive administrator rights

Administrator rights are recommended for the first user.

#### Non-Interactive Method

```bash
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  --user <ADMIN_USERNAME> \
  --password '<STRONG_PASSWORD>' \
  --admin \
  http://localhost:8008
```

This creates an administrator account such as:

```text
@<ADMIN_USERNAME>:your-domain
```

> [!NOTE]
> `User ID already taken` is not an installation failure. The user already exists from a previous script run. Sign in with the existing credentials or create another username.

## Verify Installation

Run the following checks after installation.

### 1. Container Health

```bash
sudo docker ps
```

Expected result: all bytEM containers report `Up`.

### 2. Matrix Endpoint

Open:

```text
https://matrix.bytem.your-domain.app
```

Expected result: the bytEM login page is accessible.

If the page does not load, check Nginx and SSL configuration.

### 3. bytEM Login

Open:

```text
https://bytem.your-domain.app/user/login
```

Sign in with the Matrix user created during installation.

### 4. Application Access

After login, confirm that the main bytEM application loads successfully.

If login fails:

```bash
sudo docker logs bytem-synapse --tail 50
```

> [!TIP]
> If the Homeserver field shows an unexpected domain, or login fails immediately after a fresh installation, perform a hard refresh (`Ctrl+Shift+R`) and try again.

## Upgrade bytEM

> [!IMPORTANT]
> Upgrading preserves existing Docker volumes, Matrix users, SSL certificates, domain configuration, and `.env.bytem`.

Run:

```bash
sudo ./install.sh
```

Docker pulls the latest images and recreates the containers.

You do **not** normally need to rerun:

- `env_setup.sh`
- `certbot.sh`
- `whitelist-sync.sh`

After upgrading:

```bash
sudo docker ps
```

Confirm that all containers are running, then test login with an existing user and verify that the services remain accessible.

## Appendix — Deployment Architecture

### Docker Images

| Image | Tag | Size |
|---|---|---|
| `bytem-app` | latest | 292 MB |
| `bytem-be` | latest | 408 MB |
| `bytem-bot` | latest | 378 MB |
| `postgres` | 14-alpine | 278 MB |
| `matrixdotorg/synapse` | v1.123.0 | 418 MB |
| `rabbitmq` | 3-management-alpine | 176 MB |
| `solr` | 9.5.0 | 580 MB |

> [!NOTE]
> Image sizes are reference values and may change between releases.

### Dockerfiles

| File | Purpose |
|---|---|
| `Dockerfile.backend` | Builds the Exchange server image (`bytem-be`) |
| `Dockerfile.bot` | Builds the bot image (`bytem-bot`) |
| `Dockerfile.bytemApp` | Builds the React frontend served by Nginx and includes Certbot |

### Services and Port Bindings

Format: `host_port:container_port`

| # | Container | Description | Ports |
|---|---|---|---|
| 1 | `bytem-app` | React frontend | `80:80`, `443:443`, `8448:8448` — Matrix federation via Nginx |
| 2 | `bytem-be` | Exchange server | `9999:9999` — FE, `3000:3000` — Exchange |
| 3 | `bytem-bot` | Bot(s) | `4000:4000` |
| 4 | `bytem-pwa` | Progressive Web App frontend | `8002:3002` |
| 5 | `bytem-rabbitmq` | RabbitMQ message queues | `5672:5672` — server, `15672:15672` — UI |
| 6 | `bytem-solr` | Apache Solr search engine | `8983:8983` |
| 7 | `bytem-synapse` | Matrix Synapse server | `8008:8008` — default, `8009:8009` — sliding sync |
| 8 | `bytem-synapse-db` | PostgreSQL for Synapse | `5432:5432` |

### Persistent Volumes

| Volume | Used by | Purpose |
|---|---|---|
| `bytem-rabbitmq-data` | `bytem-rabbitmq` | RabbitMQ server data |
| `bytem-rabbitmq-log` | `bytem-rabbitmq` | RabbitMQ server logs |
| `bytem-synapse-db-data` | `bytem-synapse-db` | PostgreSQL data for Matrix Synapse |
| `bytem-solr-data` | `bytem-solr` | Solr core data and configsets |

### Host-Mounted Configuration

| Path | Mounted into | Purpose |
|---|---|---|
| `generated_config_files/` | `bytem-app`, `bytem-synapse` | Nginx configs and `homeserver.yaml` |
| `certbot/` | `bytem-app` | SSL certificates |
| `.env.bytem` | `bytem-be`, `bytem-bot` | Environment variables and configuration options |

## Troubleshooting

| Symptom | Check / Action |
|---|---|
| Login page does not load | Run `sudo docker ps` and confirm `bytem-app` is up |
| `Cannot reach homeserver` | Rerun `sudo ./install.sh` |
| Login fails after fresh install | Hard refresh the browser with `Ctrl+Shift+R` |
| Login fails / Synapse errors | Run `sudo docker logs bytem-synapse --tail 50` |
| SSL is not working | Rerun `sudo ./certbot.sh` |
| Root disk is filling up | Move Docker data to dedicated storage; see **Install Docker and Clone bytEM** |

## Support

### Matrix Support Room

For installation and configuration help:

- **Room:** `#bytem-support:matrix.liberbyte.com`
- **Direct link:** [#bytem-support:matrix.liberbyte.com](https://matrix.to/#/#bytem-support:matrix.liberbyte.com)

To join through Element:

1. Open [app.element.io](https://app.element.io)
2. Select **Explore**
3. Search for `#bytem-support:matrix.liberbyte.com`
4. Join the room

## bytEM User Guide

For product usage after installation:

https://github.com/liberbyte/bytEM-public/blob/main/BYTEM_USER_GUIDE.md
