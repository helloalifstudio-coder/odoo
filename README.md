# Odoo Community — Alif local operations

This repository is a fork of [Odoo Community](https://github.com/odoo/odoo), tracking the
`20.0` series. The ERP engine and first-party applications remain upstream Odoo;
this fork adds a reproducible, local-first deployment layer and operating documentation.

## Run Odoo locally (recommended)

The supported local path is Docker Compose. It runs the source in this repository with a
separate PostgreSQL 16 database, persistent filestore, generated secrets, and ports bound
to the local machine only.

### Windows

1. Install Docker Desktop and enable its WSL 2 backend.
2. Open PowerShell in the folder where you want the repository.
3. Clone a shallow checkout (the upstream Git history is very large):

   ~~~powershell
   git clone --depth 1 --single-branch --branch alif/production-local https://github.com/helloalifstudio-coder/odoo.git
   cd odoo
   .\scripts\setup-local.ps1
   ~~~

4. Open [http://localhost:8069](http://localhost:8069).
5. On the database creation screen, use the **master password** stored in the local
   `.env` file. Choose a separate administrator email and password for the Odoo
   database user.

### Linux / macOS

Install Docker Engine or Docker Desktop with the Compose plugin, then run:

~~~bash
git clone --depth 1 --single-branch --branch alif/production-local https://github.com/helloalifstudio-coder/odoo.git
cd odoo
./scripts/setup-local.sh
~~~

Open [http://localhost:8069](http://localhost:8069) after the services start.

## Daily operations

~~~bash
# View service status
docker compose ps

# Follow Odoo logs
docker compose logs -f odoo

# Rebuild after changing source or dependencies
docker compose up --build -d

# Stop services without deleting data
docker compose down

# DESTRUCTIVE: remove containers AND all database/filestore volumes
docker compose down --volumes
~~~

Custom community modules belong in `custom-addons/` (one Odoo module per subfolder).
The folder is mounted read-only into the application container. Restart Odoo after adding or
updating a module.

## Backups

After creating a database, back it up with:

~~~bash
./scripts/backup.sh your_database_name
~~~

The script writes a PostgreSQL custom-format dump, a separate filestore archive, and SHA-256
checksums under `backups/`. Keep backups outside this machine as well. For consistent
production backups, put the instance in maintenance mode or stop writes while capturing both
the database and filestore; always test a restore before relying on a backup.

## Architecture and operating guidance

- [Architecture review](docs/ARCHITECTURE_REVIEW.md)
- [Local setup and troubleshooting](docs/LOCAL_SETUP.md)
- [Production readiness checklist](docs/PRODUCTION_CHECKLIST.md)

## Important security boundary

The included Compose stack is **for local development and single-machine use**. It binds the
web and websocket ports to `127.0.0.1` and does not publish PostgreSQL. Do not expose
this configuration directly to a LAN or the public internet. Public production deployments
need a hardened Linux host, HTTPS reverse proxy, restricted database access, database
filtering, worker sizing, monitoring, and tested off-host backups; see the production checklist.

The Compose environment creates separate PostgreSQL-superuser, Odoo database-user, and Odoo
master-password secrets. Keep `.env` private and never commit it.

## Upstream project

Odoo is a suite of integrated business applications. See the
[upstream documentation](https://www.odoo.com/documentation/20.0/) and the
[upstream source repository](https://github.com/odoo/odoo).

This fork contains the Community source tree. Odoo Enterprise add-ons are distributed
separately by Odoo and require the applicable license/subscription.
