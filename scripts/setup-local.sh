#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v docker >/dev/null 2>&1 || {
    echo "Docker is required. Install Docker Engine/Desktop with the Compose plugin." >&2
    exit 1
}
docker info >/dev/null 2>&1 || {
    echo "Docker is installed but its engine is not running." >&2
    exit 1
}

if [[ ! -f .env ]]; then
    command -v openssl >/dev/null 2>&1 || {
        echo "OpenSSL is required to generate local secrets." >&2
        exit 1
    }
    umask 077
    {
        printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 32)"
        printf 'ODOO_DB_USER=odoo\n'
        printf 'ODOO_DB_PASSWORD=%s\n' "$(openssl rand -hex 32)"
        printf 'ODOO_MASTER_PASSWORD=%s\n' "$(openssl rand -hex 32)"
        printf 'ODOO_PORT=8069\n'
        printf 'ODOO_GEVENT_PORT=8072\n'
        printf 'ODOO_LOG_LEVEL=info\n'
    } > .env
    chmod 600 .env
    echo "Generated three independent local secrets in .env. Keep this file private."
else
    echo "Existing .env found; preserving its credentials."
fi

docker compose config --quiet
docker compose up --build -d
docker compose ps

cat <<'EOF'

Odoo is starting at http://localhost:8069
The first startup can take a few minutes while the image is built.
The database master password is stored in .env; it is separate from the Odoo login.
EOF
