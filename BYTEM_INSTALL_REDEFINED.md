# bytEM Installation Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start Overview](#quick-start-overview)
3. [Step 1 — Install Docker & Clone the Repo](#step-1--install-docker--clone-the-repo)
4. [Step 2 — Environment Setup (`env_setup.sh`)](#step-2--environment-setup-env_setupsh)
5. [Step 3 — Run the Installer (`install.sh`)](#step-3--run-the-installer-installsh)
6. [Step 4 — Verify Containers](#step-4--verify-containers)
7. [Step 5 — SSL Setup (`certbot.sh`)](#step-5--ssl-setup-certbotsh)
8. [Step 6 — Whitelist Sync (`whitelist-sync.sh`)](#step-6--whitelist-sync-whitelist-syncsh)
9. [Step 7 — Create Your First User](#step-7--create-your-first-user)
10. [Step 8 — Test Your Installation](#step-8--test-your-installation)
11. [Upgrading bytEM](#upgrading-bytem)
12. [Architecture Reference](#architecture-reference)
13. [Troubleshooting](#troubleshooting)
14. [Support](#support)

---
## Video Guide for Installation

https://github.com/user-attachments/assets/73e70afb-fae8-460c-9ce4-6636fe058f05


---
## Prerequisites

Before you begin, make sure you have the following:

| Requirement | Details |
|---|---|
| **Server OS** | Ubuntu 24.04 |
| **Minimum Specs** | 2 CPU cores, 8 GB RAM, 80 GB disk |
| **Domain** | A dedicated domain or subdomain with its own IP address |
| **Credentials** | Custom credentials ready for: bot user, RabbitMQ, Synapse |

---

## Quick Start Overview

These are the high-level steps in order. Each is covered in detail below.

```
1. Install Docker & Docker Compose, clone the repo
2. sudo ./env_setup.sh      → generates config files
3. sudo ./install.sh         → deploys all services
4. sudo ./certbot.sh         → enables HTTPS
5. sudo ./whitelist-sync.sh  → joins the trusted bytEM network
6. Create your first Matrix user
7. Test the installation
```

---

## Step 1 — Install Docker & Clone the Repo

### Install Docker and Clone

```sh
sudo apt update
sudo apt install docker docker-compose

git clone https://github.com/liberbyte/bytEM-public.git
cd bytEM-public
```

> **Tip:** If `docker-compose` isn't recognized, run:
> ```sh
> sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
> ```
>
> If `git clone` fails with a permission error, use `sudo git clone ...` instead.

---

### Optional: Move Docker Data to Dedicated Storage

If your server has a dedicated storage volume (e.g. `/xxx-liberbyte`), you can relocate Docker's data directory to avoid filling up the root filesystem. **Do this before running any other scripts.**

```sh
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

# Navigate to dedicated storage and clone the repo
cd /xxx-liberbyte
```

**Why do this?** All Docker images, containers, and volumes will be stored on the larger dedicated volume, keeping your root filesystem clear. No changes to the install scripts are needed afterward.

---

## Step 2 — Environment Setup (`env_setup.sh`)

**Run this first.** It generates all configuration files needed by the application.

```sh
sudo ./env_setup.sh
```

When prompted, enter:
- Your subdomain (e.g. `liberbyte.app`)
- Your prefix (e.g. `bm4`)
- Custom credentials for the bot user, RabbitMQ, Synapse, etc.

### What this script does

- Creates the `generated_config_files/` directory
- Generates subdirectories:
  - `generated_config_files/nginx_config/`
  - `generated_config_files/synapse_config/`
- Populates config files from templates in `config_templates/`
- Generates the `.env.bytem` file from `.env.template`
- If a previous `.env.bytem` already exists, you'll be prompted to back it up before overwriting

---

## Step 3 — Run the Installer (`install.sh`)

```sh
sudo ./install.sh
```

### What this script does

- Sets correct ownership on `generated_config_files/` so the Synapse container can read it
- Pulls all Docker images and starts all containers via `docker-compose.yaml`
- Registers the bot/admin Matrix user and saves the login token to `.env.bytem`
- Restarts the full stack so all containers pick up the new token
- Patches any hardcoded domains in the frontend bundle to match your actual domain
- Creates a welcome page for the Matrix subdomain
- Configures internal networking so the app can reach the homeserver

> **Note:** If you ever see a "Cannot reach homeserver" error after restarting or upgrading, simply re-run `sudo ./install.sh` to restore the networking configuration.

---

## Step 4 — Verify Containers

After `install.sh` completes, confirm all containers are running:

```sh
sudo docker ps
```

All containers in the bytEM stack should show a status of `Up`.

---

## Step 5 — SSL Setup (`certbot.sh`)

```sh
sudo ./certbot.sh
```

You'll be prompted for an email address — this is used only for Let's Encrypt renewal notices.

### What this script does

- Bootstraps a temporary self-signed certificate so Nginx can start immediately
- Obtains (or renews) Let's Encrypt SSL certificates for your bytEM and Matrix domains
- Falls back to the self-signed certificate if Let's Encrypt is unavailable
- Regenerates Nginx configs with the correct certificate paths and reloads Nginx
- Patches any hardcoded domains in the frontend bundle

---

## Step 6 — Whitelist Sync (`whitelist-sync.sh`)

The bytEM network uses whitelisting to control which servers can communicate with your instance. Only servers on the approved list can exchange data with you.

**Why this matters:**
- **Security** — Prevents unauthorized servers from accessing your data catalog
- **Trust** — Ensures you only connect with verified bytEM instances
- **Federation control** — Defines your trusted peer network in the decentralized architecture

```sh
sudo ./whitelist-sync.sh
```

### What this script does

- Fetches the latest allowed-domain list from the bytEM registry
- Updates `homeserver.yaml` with the correct federation whitelist
- Restricts the `/solr` endpoint in Nginx to bytEM servers only
- Reloads Nginx and Matrix Synapse configs inside their containers
- Sets the bot/admin user's Matrix rate limit override so it isn't throttled by Synapse
- Restarts `bytem-synapse`, `bytem-bot`, `bytem-be`, and `bytem-app`

---

## Step 7 — Create Your First User

Creating a Matrix user is required to log in and verify the installation.

### Interactive method

```sh
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  http://localhost:8008
```

You'll be prompted for a username, password, and whether to grant admin rights (recommended for your first user).

### Non-interactive method

```sh
sudo docker exec -it bytem-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  --user test \
  --password "test" \
  --admin \
  http://localhost:8008
```

This creates the admin user `@test:your-domain`.

> **Note:** A `User ID already taken` message is not an error — the user was already created by a previous script run. Just log in with the existing credentials, or choose a different username.

---

## Step 8 — Test Your Installation

Run through these checks to confirm everything is working correctly.

### 1. Nginx / Domain Check

Open your Matrix subdomain in a browser:
```
https://matrix.bytem.your-domain.app
```
You should see the bytEM login page. If the page doesn't load, check your Nginx or SSL setup.

### 2. Login Page Check

Navigate to:
```
https://bytem.your-domain.app/user/login
```
Log in with the user credentials you created in Step 7.

### 3. Post-Login Check

After logging in, verify you can reach the main application. If login fails:

```sh
# Check Synapse logs
sudo docker logs bytem-synapse --tail 50
```

> If the Homeserver field shows an unexpected domain, or login fails right after a fresh install, do a hard refresh (`Ctrl+Shift+R`) to clear cached pages and try again.

---

## Upgrading bytEM

Upgrading preserves all existing data, users, certificates, and configurations.

```sh
sudo ./install.sh
```

**What happens:** Docker pulls the latest images and recreates the containers.

**What is preserved:** Docker volumes, Matrix users, SSL certificates, domain configs, and your `.env.bytem` file.

**What you do NOT need to re-run:**

- `env_setup.sh`
- `certbot.sh`
- `whitelist-sync.sh`

**After upgrading, verify:**

```sh
sudo docker ps        # All containers are running
```

Then test login with an existing user and confirm services are accessible.

---

## Architecture Reference

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

### Dockerfiles

| File | Purpose |
|---|---|
| `Dockerfile.backend` | Builds the Exchange server image (`bytem-be`) |
| `Dockerfile.bot` | Builds the bot image (`bytem-bot`) |
| `Dockerfile.bytemApp` | Builds the React frontend served by Nginx (includes Certbot) |

### Services & Port Bindings

Format: `host_port:container_port`

| # | Container | Description | Ports |
|---|---|---|---|
| 1 | `bytem-app` | React frontend | `80:80`, `443:443`, `8448:8448` (Matrix federation, TLS via Nginx) |
| 2 | `bytem-be` | Exchange server | `9999:9999` (FE), `3000:3000` (Exchange) |
| 3 | `bytem-bot` | Bot(s) | `4000:4000` |
| 4 | `bytem-pwa` | Progressive Web App frontend | `8002:3002` |
| 5 | `bytem-rabbitmq` | RabbitMQ message queues | `5672:5672` (server), `15672:15672` (UI) |
| 6 | `bytem-solr` | Apache Solr search engine | `8983:8983` |
| 7 | `bytem-synapse` | Matrix Synapse server | `8008:8008` (default), `8009:8009` (sliding sync) |
| 8 | `bytem-synapse-db` | PostgreSQL for Synapse | `5432:5432` |

### Persistent Volumes

| Volume | Used by | Purpose |
|---|---|---|
| `bytem-rabbitmq-data` | `bytem-rabbitmq` | RabbitMQ server data |
| `bytem-rabbitmq-log` | `bytem-rabbitmq` | RabbitMQ server logs |
| `bytem-synapse-db-data` | `bytem-synapse-db` | PostgreSQL data for Matrix Synapse |
| `bytem-solr-data` | `bytem-solr` | Solr core data and configsets |

### Host-Mounted Directories

| Path | Mounted into | Purpose |
|---|---|---|
| `generated_config_files/` | `bytem-app`, `bytem-synapse` | Nginx configs and `homeserver.yaml` |
| `certbot/` | `bytem-app` | SSL certificates |
| `.env.bytem` | `bytem-be`, `bytem-bot` | Environment variables and config options |

---

## Troubleshooting

| Symptom | What to check |
|---|---|
| Login page doesn't load | Run `sudo docker ps` — check if `bytem-app` is up |
| "Cannot reach homeserver" | Re-run `sudo ./install.sh` |
| Login fails after fresh install | Hard refresh browser (`Ctrl+Shift+R`) |
| Login fails / Synapse errors | Run `sudo docker logs bytem-synapse --tail 50` |
| SSL not working | Re-run `sudo ./certbot.sh` |
| Root disk filling up | Move Docker data to dedicated storage (see Step 1) |

> **Placeholder reminder:** Replace these values throughout your commands:
> - `your-domain` → your actual domain or subdomain
> - `USERNAME` → your Matrix/bytEM username
> - `PASSWORD` → your chosen password

---

## Support

### Matrix Support Room

Join the public support room for installation help and configuration questions:

- **Room address:** `#bytem-support:matrix.liberbyte.com`
- **Direct link:** [#bytem-support:matrix.liberbyte.com](https://matrix.to/#/#bytem-install-admin:matrix.liberbyte.com)

**To join via Element:**

1. Open [app.element.io](https://app.element.io)
2. Click **Explore**
3. Search for `#bytem-support:matrix.liberbyte.com`
4. Join the room

### BytEM User Guide Link

https://github.com/liberbyte/bytEM-public/blob/main/BYTEM_USER_GUIDE.md
