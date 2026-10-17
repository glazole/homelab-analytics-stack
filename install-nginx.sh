#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DST="${1:-$HOME/projects/homelab/outline_wiki/nginx/conf.d}"
[[ -d "$DST" ]] || { echo "Missing Nginx conf.d directory: $DST" >&2; exit 1; }
docker inspect homelab-nginx >/dev/null 2>&1 || { echo 'homelab-nginx not running' >&2; exit 1; }
backup_dir="$(mktemp -d)"
rollback() {
  for f in pgdb.conf clickdb.conf metabase.conf; do
    if [[ -e "$backup_dir/$f" ]]; then
      cp "$backup_dir/$f" "$DST/$f"
    else
      rm -f "$DST/$f"
    fi
  done
}
for f in pgdb.conf clickdb.conf metabase.conf; do
  [[ ! -e "$DST/$f" ]] || cp "$DST/$f" "$backup_dir/$f"
  cp "$ROOT/nginx/$f" "$DST/$f"
done
if ! docker exec homelab-nginx nginx -t; then
  echo 'Nginx validation failed; restoring previous files.' >&2
  rollback
  docker exec homelab-nginx nginx -t || true
  exit 1
fi
docker exec homelab-nginx nginx -s reload
rm -rf "$backup_dir"
echo 'Nginx reloaded with pgdb, clickdb, and metabase vhosts.'
