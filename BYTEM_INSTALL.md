# bytEM installation and upgrade guide

## Architecture

The public installer pulls the images produced by the private/source
repository's GitHub Actions workflow:

| Service | Image | Purpose |
| --- | --- | --- |
| `bytem-nginx` | `liberbyteadmin/bytem:nginx` | TLS, reverse proxy, Matrix discovery and federation |
| `bytem-pwa` | `liberbyteadmin/bytem:pwa` | The single merged frontend |
| `bytem-be` | `liberbyteadmin/bytem:be` | API gateway |
| `bytem-bot` | `liberbyteadmin/bytem:bot` | Matrix workflow bot |
| `bytem-synapse` | `liberbyteadmin/bytem:synapse` | Matrix Synapse 1.159 with bytEM modules |
| `bytem-solr` | `liberbyteadmin/bytem:solr` | Search index |

PostgreSQL and RabbitMQ use their upstream images.

There is no `bytem-app` service and no generated host-side nginx or Synapse
configuration. The nginx and Synapse images generate their configuration from
`.env`. Synapse data, including its signing key and media, lives in the
`bytem-synapse-data` volume.

## Prerequisites

- Docker Engine with Compose v2 (`docker compose version`)
- at least 8 GB RAM available for the Synapse container limit
- DNS A/AAAA records for the application and Matrix names
- inbound TCP 80, 443, and 8448
- outbound HTTPS for image pulls and federation market-list retrieval

For a base domain `example.com` and prefix `bm4`, setup creates:

- `bytem.bm4.example.com`
- `matrix.bytem.bm4.example.com`

Both names must resolve to the Docker host before certificate issuance.

## Fresh installation

```bash
git clone https://github.com/liberbyte/bytEM-public.git
cd bytEM-public
chmod +x env_setup.sh certbot.sh install.sh whitelist-sync.sh scripts/*.sh
./env_setup.sh
./install.sh
```

The setup asks separately for:

1. Test/admin account credentials, used by a person to sign in.
2. Bot account credentials, used only by `bytem-be` and `bytem-bot`.

Synapse creates both accounts on its first healthy start. They must have
different usernames and should have different passwords. SSO client credentials
are no longer part of installation.

Infrastructure passwords and stable Synapse secrets are generated
automatically. Store `.env` in a password manager or secure backup and never
commit it.

`install.sh` then:

1. validates Compose interpolation;
2. pulls the published images;
3. obtains missing TLS certificates;
4. migrates legacy Synapse `/data`, when present;
5. starts the stack and waits for health checks.

The backend and bot authenticate with `BOT_USERNAME` and `BOT_PASSWORD` at
runtime. They refresh the bot access token in memory. Installation does not put
a test-user token into bot settings, write a token back into `.env`, or restart
the stack merely to propagate a token.

## TLS

`install.sh` calls `certbot.sh` automatically when either certificate is
missing. For renewal:

```bash
./certbot.sh
```

For local-only testing where public Let's Encrypt validation is impossible:

```bash
./certbot.sh --self-signed
./install.sh
```

Self-signed certificates cause browser warnings and are not suitable for Matrix
federation in production.

## Upgrade an existing installation

Back up state first:

```bash
./scripts/pre_reinstall_check.sh
cp .env "/secure/location/bytem.env.$(date +%F)"
```

Then update and install:

```bash
git pull --ff-only
./install.sh
```

The installer does not run `docker compose down -v`, prune all images, replace
`.env`, or delete certificates. The existing PostgreSQL, Solr, RabbitMQ, and
Synapse named volumes are retained.

When upgrading from the old `bytem-app` Compose layout, the installer detects
`generated_config_files/synapse_config`. If the new `bytem-synapse-data` volume
is empty, it copies the old `/data` contents into that volume before starting
Synapse. This preserves the server signing key and media. The old
`generated_config_files` directory is not deleted automatically; remove it only
after verifying the upgraded deployment and retaining a backup.

If you intentionally need a replacement `.env`, the setup backs up the old one:

```bash
./env_setup.sh --force
```

This is also the migration path for an old `.env` that used the bot as its test
admin. Enter the existing domains plus new, separate account credentials. The
script preserves existing database/search passwords and stable Synapse secrets
unless you explicitly override those values in the command environment.

Changing the Synapse secrets or losing its signing key can invalidate sessions
or break federation identity, so do not regenerate them during a routine image
upgrade.

## Verification and operation

```bash
docker compose ps
docker compose logs --tail 100 bytem-synapse bytem-be bytem-bot bytem-nginx
set -a; source .env; set +a
curl -fsS "https://${DOMAIN_NAME}/api/auth/health"
curl -fsS "https://${MATRIX_SERVER_NAME}/_matrix/client/versions"
```

Run the end-to-end workflow with the test account stored in `.env`:

```bash
./scripts/test_workflow.sh
```

The test account and bot account remain separate: the test logs in and creates
the test rooms; the bot is invited to process them.

Synapse builds its federation whitelist at container start from
`FEDERATION_MARKET_LIST_URL` (or `MARKET_LIST`). To fetch it again and inspect
the resulting active list:

```bash
./whitelist-sync.sh
```

## Common problems

| Symptom | Check |
| --- | --- |
| nginx repeatedly restarts | Both certificate paths exist under `certbot/conf/live/`; run `./certbot.sh` |
| Let's Encrypt validation fails | Both DNS names point here, port 80 is open, and no unrelated process occupies it |
| bot/backend exits after startup | `BOT_USERNAME` and `BOT_PASSWORD` match the separate bot account created by Synapse |
| test login fails | Use `TEST_USERNAME`/`TEST_PASSWORD`, not the bot credentials |
| Synapse cannot start | Check `docker compose logs bytem-synapse bytem-synapse-db` and verify stable secrets in `.env` |
| cross-instance exchange fails | Run `./whitelist-sync.sh` and check market-list reachability |
| old `/pwa/...` bookmark | nginx redirects it to the equivalent root PWA route |
