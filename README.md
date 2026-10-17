# HP Homelab analytics extensions · pg4 + ClickHouse + Metabase

Three **independent** Compose projects under the existing `outline-network` (shared Nginx) and `homelab-db` (private PostgreSQL and analytics traffic). No changes to the existing pg1/pg2/pg3/Outline/Airflow/Sparkice Compose files, and **no new host ports**.

| HTTPS site (via existing `homelab-nginx`) | Backend service | Private Docker endpoint |
|---|---|---|
| `pgdb.handyman.moscow` | pgAdmin 4 | `pgadmin:80` |
| `clickdb.handyman.moscow` | ClickHouse `/play` | `clickhouse:8123` |
| `metabase.handyman.moscow` | Metabase | `metabase:3000` |

## Actual databases and roles

- `pg4` (`postgres:17`) on `homelab-db` stores two new databases:
  - `metabase`: *application database*, owned by `metabase_app`; stores Metabase configuration, users, dashboards.
  - `analytics`: independent, empty analytical sandbox, owned by `analytics_app` and readable by `analytics_ro`.
- Metabase **also** connects to ClickHouse as an analytic data source later in its UI. Merely configuring the `metabase` app database does *not* make `analytics` or ClickHouse available as query sources.
- ClickHouse 26.7 creates database `analytics` and user `homelab`. Credentials are generated locally.

## Initial preparation on HP server

Preflight:

```bash
docker network inspect homelab-db outline-network >/dev/null
docker ps --format 'table {{.Names}}\t{{.Status}}'
free -h
```

Extract this archive into `~/projects/homelab/analytics-stack` (the archive already contains root `homelab-analytics-stack/`; rename only the top directory if desired). The existing `outline_wiki/nginx/conf.d` is not overwritten until `install-nginx.sh` is executed. Check for pre-existing server blocks for new hostnames first.

```bash
cd ~/projects/homelab/homelab-analytics-stack
./pg4/prepare.sh   # creates secrets and pg4/.env; exits until you edit the login email
nano pg4/.env      # set PGADMIN_DEFAULT_EMAIL to an address you control
./start.sh         # pg4 and pgAdmin → ClickHouse → Metabase
./install-nginx.sh # validates and reloads existing homelab-nginx
```

Start only pg4 first if preferred:

```bash
./pg4/prepare.sh
cd pg4
docker compose up -d
docker compose ps
```

Do **not** start Metabase before first-time pg4 initdb finished. Postgres init scripts run **once only**, when the Docker volume is empty. The startup script checks whether the `metabase` database has appeared.

DNS for all three hostnames must reach the same `homelab-nginx`. TLS certificate `handyman.moscow.pem` must cover those subdomains; if it is issued by a private CA, browsers/clients must trust that CA. Existing Nginx certificates are reused, not replaced.

## Database details

Postgres TCP host from other services on `homelab-db`: `pg4:5432`. No `5432` is opened on the HP host. `pgdb` is pgAdmin **only**.

Retrieve local bootstrap credentials *on the HP server* (never send them in chat or Git):

```bash
cat pg4/secrets/pg4_admin_password
cat pg4/secrets/pgadmin_password
cat pg4/secrets/analytics_ro_password
```

Use them in pgAdmin and in Metabase's Admin > Databases settings.

Metabase application storage is already configured automatically via `MB_DB_TYPE=postgres`, `MB_DB_HOST=pg4`, `MB_DB_DBNAME=metabase`, `MB_DB_USER=metabase_app`, `MB_DB_PASS_FILE=...`.

Add two separate **data sources** in Metabase under Admin > Databases:

| Data source | Host | Port | Database | Login |
|---|---|---|---|---|
| PostgreSQL | `pg4` | 5432 | `analytics` | `analytics_ro` |
| ClickHouse | `clickhouse` | 8123 | `analytics` | `homelab` |

For ClickHouse enter the `CLICKHOUSE_PASSWORD` from `clickhouse/.env`. The Metabase ClickHouse driver is built-in in modern versions, not a separate plugin.

## Smoke tests

```bash
docker exec pg4 pg_isready -U pg4_admin -d metabase
docker exec pg4 psql -U pg4_admin -d postgres -tAc "SELECT datname FROM pg_database WHERE datname IN ('metabase','analytics') ORDER BY 1"
docker exec homelab-clickhouse clickhouse-client --query 'SELECT version()' --user homelab --password "$(sed -n 's/^CLICKHOUSE_PASSWORD=//p' clickhouse/.env)"
docker exec homelab-nginx nginx -t
curl -I https://pgdb.handyman.moscow/
curl -I https://clickdb.handyman.moscow/
curl -I https://metabase.handyman.moscow/
```

To check basic reachability inside Docker without exposing native DB ports:

```bash
docker exec homelab-nginx getent hosts pgadmin clickhouse metabase
docker exec homelab-metabase getent hosts pg4 clickhouse
```

`stop.sh` stops only these stacks, without deleting volumes. **Never use `docker compose down -v`** unless deliberately deleting the data. Preserve backups of `pg4` and ClickHouse named volumes, the Metabase app database, and `pg4/secrets`/`clickhouse/.env`.

## Security and capacity

1. **Critical:** ClickHouse's HTTP URL exposes a SQL endpoint, not just an HTML interface. Require strong DB credentials. Prefer VPN/private DNS + a Keycloak-aware access gateway before any Internet exposure. pgAdmin and Metabase also should not be publicly available to anonymous users.
2. Distinct secrets, generated via `openssl rand -hex 32`, stay out of Git; `.env` is ignored. `pg4` has a separate privileged login; `analytics_ro` is for BI read-only queries.
3. `metabase/metabase:latest` is used as requested, but for repeatable deployments, pin an audited version or immutable digest and test upgrades before deploying.
4. This HP has ~15 GiB RAM. Pg4 768 MiB + pgAdmin 640 MiB + ClickHouse 3 GiB + Metabase 1800 MiB are **container caps, not reservations**. Spark/Jupyter/Airflow/Keycloak can push total real memory above available capacity. Avoid heavy Spark and ClickHouse workloads concurrently until observed.
5. This package was reviewed statically; the new containers and domains were not run/tested on the user's HP host. Verify actual Docker image tags and startup logs before trusting the environment.
