# Local setup and operations

## Compatibility

This repository tracks Odoo 20.0. The checked-in release metadata sets Python minimum to
3.12, maximum to 3.14 (exclusive), and PostgreSQL minimum to 16. The local container build
uses Ubuntu 24.04 / Python 3.12 and PostgreSQL 16 to stay on the supported baseline.

Docker Compose is the recommended path on Windows, macOS, and Linux. On Windows, use Docker
Desktop with WSL 2 enabled; do not try to install the complete Odoo development stack into
native Windows Python for a long-lived deployment.

## 1. Clone a shallow checkout

The fork is very large because of its Git history. Fetch only the current branch and its
latest snapshot:

~~~bash
git clone --depth 1 --single-branch --branch alif/production-local https://github.com/helloalifstudio-coder/odoo.git
cd odoo
~~~

For Windows PowerShell, the same Git command works.

## 2. Generate secrets and start services

Windows PowerShell:

~~~powershell
.\scripts\setup-local.ps1
~~~

Linux / macOS:

~~~bash
chmod +x scripts/setup-local.sh
./scripts/setup-local.sh
~~~

The setup script creates a private `.env` containing three independent random secrets:
- PostgreSQL superuser password (database administration only).
- Odoo database role password (a non-superuser role with database-creation permission).
- Odoo master password (database manager operations).

The scripts never print the secrets to the terminal. Keep `.env` private. The repository
ignores local environment files.

## 3. Create the first Odoo database

1. Open [http://localhost:8069](http://localhost:8069).
2. The database manager appears because the local profile intentionally enables it.
3. Read `ODOO_MASTER_PASSWORD` from `.env` and enter it as the master password.
4. Choose a database name, email, and a strong administrator password. The Odoo administrator
   login is separate from both PostgreSQL passwords and the master password.
5. Select the language and country. Install only the business applications you need.

The local stack publishes the HTTP and websocket ports on `127.0.0.1` only.
PostgreSQL has no host-published port. It is not intended to be reachable from another machine.

## 4. Daily commands

~~~bash
# Status
docker compose ps

# Odoo logs
docker compose logs -f odoo

# PostgreSQL logs
docker compose logs -f db

# Rebuild the Odoo image after source/dependency changes
docker compose up --build -d

# Stop while preserving database and filestore volumes
docker compose down

# Remove all data (irreversible)
docker compose down --volumes
~~~

Do not run `docker compose down --volumes` unless you intentionally want to erase the
PostgreSQL database and Odoo filestore.

## 5. Add custom modules

Create one directory per custom Odoo module under `custom-addons/`. Each module must
contain `__manifest__.py` and `__init__.py`. The directory is mounted read-only.
After copying or updating modules, restart the service:

~~~bash
docker compose restart odoo
~~~

Use a version-controlled dependency manifest for third-party modules. Do not install arbitrary
third-party add-ons into a business database without reviewing their code and license.

## 6. Backup

Run from Linux, macOS, or WSL:

~~~bash
./scripts/backup.sh my_database
~~~

The command creates a PostgreSQL custom-format dump, a filestore archive, and checksum file in
`backups/`. Backup files can contain sensitive customer, employee, invoice, and attachment
data. Restrict access, encrypt off-host copies, and define a retention policy.

For the most reliable snapshot, schedule a maintenance window or stop user writes while both
database and filestore are captured. For a consistent production backup, use Odoo's supported
database backup procedure (including the filestore) or a coordinated database/filestore snapshot.

### Restore outline

Restore into a separate test instance first. Stop the Odoo service, recreate the target database,
restore the PostgreSQL dump using `pg_restore --no-owner --no-acl`, and restore the
matching filestore archive under `/var/lib/odoo/filestore/<database>` inside the Odoo
data volume. Start Odoo only after both pieces have been restored. Never restore over the only
copy of a live database.

## 7. Troubleshooting

**Port 8069 is already in use**

Set `ODOO_PORT` to a free host port in `.env`, then run
`docker compose up -d` again. The container still listens on 8069 internally.

**The database role cannot log in after editing .env**

The PostgreSQL initialization script runs only when the `postgres-data` volume is first
created. Changing a password in `.env` does not rotate the role password in an existing
volume. Update the role inside PostgreSQL deliberately, then update the matching secret; do not
delete the volume just to rotate credentials unless you intend to discard the data.

**Odoo cannot connect to PostgreSQL**

Run `docker compose ps` and `docker compose logs db`. The Odoo service waits for
the database role to be usable before starting. Check that the app role and password match.

**PDF reports do not render**

Check that the wkhtmltopdf binary is installed in the image and that the report process can
execute it. Rebuild the image after Dockerfile changes.

**A custom module is not visible**

Check the module folder layout, manifest, Python import files, and Odoo logs. Confirm the
`custom-addons` directory is on the configured add-ons path.

## Local security defaults

- Odoo runs as a non-root container user.
- PostgreSQL and Odoo data live in named volumes.
- PostgreSQL is not exposed on a host port.
- Odoo host ports bind to loopback, not all network interfaces.
- PostgreSQL has a separate non-superuser Odoo role.
- Runtime configuration is created with restrictive file permissions.
- Credentials are generated locally and are not committed.

These defaults are for local development. Review the separate production checklist before
exposing an instance to a network.
