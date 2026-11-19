# Odoo 20.0 architecture and repository readiness review

**Repository:** `helloalifstudio-coder/odoo`  
**Reviewed ref:** `alif/production-local` (initial fork state, before the local-operations hardening commit)  
**Upstream:** `odoo/odoo`  
**Review scope:** repository layout, execution model, persistence, dependency installation, and self-hosted local operations.

## Executive assessment

This repository is a fork of the upstream Odoo Community ERP, not a small custom application.
The upstream server and its first-party add-ons provide the business application platform. The
main gap in the fork's initial state was operational: its README directed users to generic
upstream source-install instructions, while the repository did not contain a first-party
Compose stack, generated-secret workflow, local backup helper, or a fork-specific runbook.

The hardening change deliberately keeps Odoo's core code intact and adds an isolated deployment
layer. That makes upstream synchronization easier and avoids turning an upstream ERP fork into
an unreviewed core rewrite.

## Architecture map

| Area | Repository location | Responsibility |
|---|---|---|
| CLI entry point | `odoo-bin` | Thin executable that invokes `odoo.cli.main()` |
| Server framework | `odoo/` | Configuration, services, HTTP stack, security, ORM, SQL integration, registry, and developer tooling |
| First-party applications | `addons/` | Business applications and their models, views, controllers, reports, assets, and module manifests |
| Python dependencies | `requirements.txt` | Dependency pins/markers for the supported Python versions and platforms |
| Python package metadata | `setup.py`, `setup.cfg`, `MANIFEST.in` | Package/build metadata and installation entry point |
| Native packaging | `debian/`, `setup/` | Debian service/package integration and Windows packaging resources |
| Documentation | `doc/`, `README.md` | Upstream developer and operator documentation |

### Request and data flow

1. A browser connects to the Odoo HTTP service (default port 8069).
2. Odoo resolves the requested database and loads the corresponding module registry.
3. Controllers and model methods execute business logic through the ORM.
4. The ORM issues SQL through Odoo's database layer to PostgreSQL.
5. Binary attachments and generated files are stored in the Odoo data directory's filestore;
   database rows hold the associated metadata and references.
6. The web client is served by Odoo's web add-on and the assets shipped by the installed modules.

The database and filestore therefore form one logical business-data set. Backing up only
PostgreSQL is not a complete backup when the database references files in the filestore.

## Execution and deployment model

Odoo is a Python server with a module registry, PostgreSQL persistence, and HTTP/websocket
services. The local setup uses `workers = 0` for a simple, single-machine developer
instance and one cron thread. This keeps startup and debugging straightforward; it is not a
production concurrency configuration.

A public production deployment should use a supported Linux host, a trusted TLS reverse proxy,
appropriate prefork workers and gevent/websocket routing, database filtering, and resource limits
sized from observed workload. Odoo's `proxy_mode` must only be enabled behind a trusted
reverse proxy because it changes how forwarded request headers are interpreted.

## Initial-state findings

- The fork tracks the upstream `20.0` series and its release metadata requires Python
  3.12 or later (3.14 is excluded) and PostgreSQL 16 or later.
- The root README was the upstream generic introduction and linked to upstream setup guidance.
- The root tree had no project-owned `Dockerfile`, Compose file, local setup scripts,
  environment template, or local-stack CI smoke test.
- The existing upstream package metadata and dependency manifest were present; duplicating or
  replacing Odoo's dependency list would create drift.
- The fork's GitHub repository metadata reported a very large repository size. A shallow,
  single-branch clone is the practical default for local setup because it avoids fetching the
  complete Git history.
- The repository is the Community source tree. Enterprise add-ons are maintained separately
  and are not included in this fork.

## Hardening decisions implemented

1. **Build from this checkout.** The Dockerfile copies the current repository source and installs
   its checked-in requirements; it does not silently run a different prebuilt Odoo application.
2. **Supported baseline.** The image uses Ubuntu 24.04 / Python 3.12 and PostgreSQL 16.
3. **Least privilege.** PostgreSQL initializes a dedicated Odoo login role with database-creation
   permission but without superuser or role-management privileges. Odoo itself runs as a
   non-root Linux user.
4. **Separate secrets.** PostgreSQL administration, the Odoo database role, and Odoo's database
   manager master password use independent random values.
5. **Local-only network surface.** HTTP and websocket ports bind to `127.0.0.1`.
   PostgreSQL is only reachable on the Compose network.
6. **Persistent business data.** PostgreSQL data and Odoo's data/filestore use named volumes.
7. **Operational basics.** Container health checks, bounded container logs, backup helper,
   setup scripts, architecture notes, and a Compose smoke-test workflow are included.

## Remaining validation and production gates

The GitHub repository edit itself does not prove that a Docker image has been built on the
user's machine. The added GitHub Actions smoke test must pass, and the first local run should
still verify database creation, login, module installation, attachment upload/download, PDF
reports, scheduled jobs, email configuration, backup, and restore.

Before a public production launch, complete the controls in
`docs/PRODUCTION_CHECKLIST.md`. In particular, do not reuse the local Compose profile
unchanged as an internet-facing production configuration.
