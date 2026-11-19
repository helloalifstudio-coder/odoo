#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DATABASE="${1:-}"
if [[ -z "$DATABASE" ]]; then
    echo "Usage: $0 <database_name> [backup_directory]" >&2
    exit 2
fi
if [[ ! "$DATABASE" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Database names may contain only letters, numbers, and underscores." >&2
    exit 2
fi

BACKUP_DIR="${2:-$ROOT/backups}"
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DB_DUMP="$BACKUP_DIR/${DATABASE}_${STAMP}.dump"
FILESTORE="$BACKUP_DIR/${DATABASE}_${STAMP}_filestore.tar.gz"

echo "Dumping PostgreSQL database ${DATABASE}..."
docker compose exec -T db sh -ec \
    'PGPASSWORD="$ODOO_DB_PASSWORD" pg_dump -h 127.0.0.1 -U "$ODOO_DB_USER" -d "$1" -Fc --no-owner --no-acl' \
    sh "$DATABASE" > "$DB_DUMP"

echo "Archiving the Odoo filestore..."
docker compose exec -T odoo sh -ec \
    'cd /var/lib/odoo/filestore; if [ -d "$1" ]; then tar -czf - "$1"; else tar -czf - --files-from /dev/null; fi' \
    sh "$DATABASE" > "$FILESTORE"

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$DB_DUMP" "$FILESTORE" > "$BACKUP_DIR/${DATABASE}_${STAMP}.sha256"
else
    shasum -a 256 "$DB_DUMP" "$FILESTORE" > "$BACKUP_DIR/${DATABASE}_${STAMP}.sha256"
fi

echo "Backup files created:"
printf '  %s\n  %s\n' "$DB_DUMP" "$FILESTORE"
echo "Keep a copy off this machine and validate it with a restore drill."
