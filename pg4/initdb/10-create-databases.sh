#!/usr/bin/env bash
set -Eeuo pipefail
# Runs ONLY when pg4-data is empty. Do not depend on initdb scripts for upgrades.
mb_pass="$(cat /run/secrets/metabase_app_password)"
app_pass="$(cat /run/secrets/analytics_app_password)"
ro_pass="$(cat /run/secrets/analytics_ro_password)"
psql --username "$POSTGRES_USER" --dbname postgres -v ON_ERROR_STOP=1 \
  -v mbpass="$mb_pass" -v apppass="$app_pass" -v ropass="$ro_pass" <<'SQL'
CREATE ROLE metabase_app LOGIN PASSWORD :'mbpass';
CREATE DATABASE metabase OWNER metabase_app ENCODING 'UTF8';
CREATE ROLE analytics_app LOGIN PASSWORD :'apppass';
CREATE ROLE analytics_ro LOGIN PASSWORD :'ropass';
CREATE DATABASE analytics OWNER analytics_app ENCODING 'UTF8';
GRANT CONNECT ON DATABASE analytics TO analytics_ro;
SQL
psql --username "$POSTGRES_USER" --dbname analytics -v ON_ERROR_STOP=1 <<'SQL'
GRANT USAGE ON SCHEMA public TO analytics_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE analytics_app IN SCHEMA public
  GRANT SELECT ON TABLES TO analytics_ro;
SQL
