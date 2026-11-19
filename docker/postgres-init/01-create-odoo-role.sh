#!/usr/bin/env bash
set -Eeuo pipefail

: "${ODOO_DB_USER:=odoo}"
: "${ODOO_DB_PASSWORD:?ODOO_DB_PASSWORD must be set}"

# The application role can create databases, but is deliberately not a superuser.
psql --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" \
    --set=app_user="${ODOO_DB_USER}" \
    --set=app_password="${ODOO_DB_PASSWORD}" <<'SQL'
SELECT format(
    'CREATE ROLE %I LOGIN CREATEDB NOSUPERUSER NOCREATEROLE NOREPLICATION PASSWORD %L',
    :'app_user',
    :'app_password'
)
\gexec
SQL
