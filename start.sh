#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
for net in homelab-db outline-network; do
  docker network inspect "$net" >/dev/null || { echo "Missing network: $net" >&2; exit 1; }
done
"$ROOT/pg4/prepare.sh"
"$ROOT/clickhouse/prepare.sh"
(cd "$ROOT/pg4" && docker compose config --quiet && docker compose up -d)
echo 'Checking pg4 application database created on first boot...'
ready=no
for i in $(seq 1 60); do
  if docker exec pg4 psql -U pg4_admin -d metabase -tAc 'SELECT 1' 2>/dev/null | grep -qx 1; then
    ready=yes; break
  fi
  sleep 2
done
[[ "$ready" == yes ]] || { echo 'pg4/metabase initialization not ready; check docker logs pg4' >&2; exit 1; }
(cd "$ROOT/clickhouse" && docker compose config --quiet && docker compose up -d)
(cd "$ROOT/metabase" && docker compose config --quiet && docker compose up -d)
echo 'Stacks started; inspect their health before installing Nginx.'
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'NAMES|pg4|pgadmin|clickhouse|metabase'
