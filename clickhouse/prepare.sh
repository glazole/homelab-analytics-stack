#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
umask 077
if [[ ! -e .env ]]; then
  pwd="$(openssl rand -hex 32)"
  printf 'CLICKHOUSE_USER=homelab\nCLICKHOUSE_PASSWORD=%s\n' "$pwd" > .env
  chmod 600 .env
fi
if grep -q 'REPLACE_WITH_GENERATED_SECRET' .env; then
  echo 'Replace placeholder CLICKHOUSE_PASSWORD in clickhouse/.env' >&2
  exit 1
fi
echo 'ClickHouse local credentials present.'
