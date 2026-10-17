#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
umask 077
mkdir -p secrets
for name in pg4_admin metabase_app analytics_app analytics_ro pgadmin; do
  file="secrets/${name}_password"
  if [[ ! -s "$file" ]]; then
    openssl rand -hex 32 > "$file"
    chmod 600 "$file"
  fi
done
if [[ ! -e .env ]]; then cp .env.example .env; chmod 600 .env; fi
if grep -q 'admin@example.com' .env; then
  echo 'Edit pg4/.env: replace admin@example.com with your own pgAdmin login email.' >&2
  exit 1
fi
# File-backed Docker secrets use host filesystem permissions.
# PostgreSQL init scripts must read secrets as the postgres user.
PG_GID="$(docker run --rm --entrypoint id postgres:17 -g postgres)"

sudo chgrp "$PG_GID" \
  secrets/{pg4_admin,metabase_app,analytics_app,analytics_ro}_password

chmod 640 \
  secrets/{pg4_admin,metabase_app,analytics_app,analytics_ro}_password

# pgAdmin runs as UID/GID 5050.
sudo chgrp 5050 secrets/pgadmin_password
chmod 640 secrets/pgadmin_password
echo 'pg4 secrets present, pgAdmin login email configured.'
