#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
for app in metabase clickhouse pg4; do
  (cd "$ROOT/$app" && docker compose stop)
done
