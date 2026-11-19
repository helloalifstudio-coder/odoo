#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

: "${ODOO_MASTER_PASSWORD:?ODOO_MASTER_PASSWORD must be set}"
: "${ODOO_DB_HOST:=db}"
: "${ODOO_DB_PORT:=5432}"
: "${ODOO_DB_USER:=odoo}"
: "${ODOO_DB_PASSWORD:?ODOO_DB_PASSWORD must be set}"
: "${ODOO_LOG_LEVEL:=info}"

# Keep secrets out of command-line arguments and generate a private runtime config.
/opt/odoo-venv/bin/python - <<'PY'
import configparser
import os

config = configparser.ConfigParser(interpolation=None)
config["options"] = {
    "admin_passwd": os.environ["ODOO_MASTER_PASSWORD"],
    "db_host": os.environ.get("ODOO_DB_HOST", "db"),
    "db_port": os.environ.get("ODOO_DB_PORT", "5432"),
    "db_user": os.environ.get("ODOO_DB_USER", "odoo"),
    "db_password": os.environ["ODOO_DB_PASSWORD"],
    "data_dir": "/var/lib/odoo",
    "addons_path": "/opt/odoo/odoo/addons,/opt/odoo/addons,/mnt/extra-addons",
    "http_interface": "0.0.0.0",
    "http_port": "8069",
    "gevent_port": "8072",
    "proxy_mode": "False",
    "list_db": "True",
    "workers": "0",
    "max_cron_threads": "1",
    "log_level": os.environ.get("ODOO_LOG_LEVEL", "info"),
}
with open("/tmp/odoo.conf", "w", encoding="utf-8") as config_file:
    config.write(config_file)
os.chmod("/tmp/odoo.conf", 0o600)
PY

# Wait for the restricted Odoo database role to become usable.
/opt/odoo-venv/bin/python - <<'PY'
import os
import time
import psycopg2

settings = {
    "host": os.environ.get("ODOO_DB_HOST", "db"),
    "port": int(os.environ.get("ODOO_DB_PORT", "5432")),
    "user": os.environ.get("ODOO_DB_USER", "odoo"),
    "password": os.environ["ODOO_DB_PASSWORD"],
    "dbname": "postgres",
    "connect_timeout": 3,
}
for attempt in range(1, 31):
    try:
        connection = psycopg2.connect(**settings)
        connection.close()
        break
    except psycopg2.OperationalError:
        if attempt == 30:
            raise
        print(f"Waiting for PostgreSQL (attempt {attempt}/30)...", flush=True)
        time.sleep(2)
PY

exec /opt/odoo-venv/bin/python /opt/odoo/odoo-bin --config=/tmp/odoo.conf "$@"
