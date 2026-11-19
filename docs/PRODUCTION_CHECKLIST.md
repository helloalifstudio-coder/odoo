# Production readiness checklist

This checklist separates a working local Odoo installation from a secure, supportable,
internet-facing ERP deployment. The repository's `compose.yaml` is intentionally
localhost-only and is not a production reverse-proxy configuration.

## 1. Host and release management

- [ ] Deploy on a supported Linux distribution (for example, Ubuntu 24.04 LTS).
- [ ] Pin the deployment to a reviewed Odoo commit or release tag; do not deploy an unreviewed
      moving branch head.
- [ ] Keep a tested rollback image and matching database/filestore backup.
- [ ] Apply OS security updates and reboot maintenance windows deliberately.
- [ ] Use a dedicated host/service identity; do not run Odoo as root.
- [ ] Record the exact Python, PostgreSQL, operating-system, add-on, and Odoo revisions.

Odoo 20.0's source metadata declares Python 3.12+ (below 3.14) and PostgreSQL 16+.

## 2. Network and reverse proxy

- [ ] Put Odoo behind a maintained reverse proxy with valid TLS certificates.
- [ ] Expose only HTTPS (normally 443) to the internet. Keep PostgreSQL private.
- [ ] Bind Odoo's backend ports to a private interface or private container network.
- [ ] Route normal HTTP requests to Odoo's HTTP port and `/websocket` requests to
      the gevent/websocket port.
- [ ] Forward the host, client IP, and HTTPS scheme headers correctly.
- [ ] Enable Odoo `proxy_mode = True` only when the proxy is trusted and direct
      untrusted access to the backend is blocked.
- [ ] Set secure cookie flags and HSTS at the TLS proxy; review upload size and request timeouts.
- [ ] Do not expose the database manager or database selector publicly.

Odoo's deployment documentation includes a reverse-proxy example with a separate websocket
upstream. Keep that routing aligned with the exact Odoo 20.0 documentation when configuring
Nginx or another proxy.

## 3. Database and secrets

- [ ] Use a dedicated PostgreSQL role for Odoo. Do not connect Odoo as the PostgreSQL
      superuser.
- [ ] Store database credentials and Odoo's master password in a managed secret store or
      protected secret files; do not store them in Git or plain-text deployment logs.
- [ ] Use strong, unique passwords and rotate them through a planned procedure.
- [ ] Set `list_db = False` / `--no-database-list` and configure a strict
      `dbfilter` for the intended production database.
- [ ] Restrict database network access to the Odoo application nodes and approved administrators.
- [ ] Require TLS for database connections when traffic crosses an untrusted network.
- [ ] Review database extensions, backup encryption, retention, and restore access.

The local profile intentionally enables the database manager for initial setup. Do not carry
that setting into a public deployment.

## 4. Odoo runtime and capacity

- [ ] Enable prefork workers for production and size workers, gevent workers, CPU limits, and
      memory limits against measured concurrency and available RAM.
- [ ] Configure request, CPU-time, real-time, and memory limits appropriate to the workload.
- [ ] Size PostgreSQL connections for the combined Odoo worker and cron workload.
- [ ] Keep the gevent/websocket service available through the reverse proxy.
- [ ] Configure outgoing SMTP and inbound mail gateways, verify SPF/DKIM/DMARC, and test
      password reset and business notifications.
- [ ] Test scheduled jobs, payment providers, webhooks, printing, and integrations end to end.
- [ ] Ensure system time and timezone handling are correct.

Do not copy generic worker counts from another deployment. Measure CPU, memory, connection
usage, queue latency, and request duration under representative business traffic.

## 5. Data durability and disaster recovery

- [ ] Back up PostgreSQL and the matching Odoo filestore as one coordinated recovery point.
- [ ] Encrypt backups and send them off-host/off-site.
- [ ] Define RPO/RTO and a retention policy with the business owner.
- [ ] Test full database plus filestore restoration into an isolated environment.
- [ ] Rehearse recovery after host loss, disk exhaustion, accidental deletion, and failed upgrade.
- [ ] Monitor volume capacity, backup age, backup failures, and restore-test results.
- [ ] Avoid treating a live filesystem copy and a separate database dump as automatically
      transactionally consistent.

## 6. Add-ons, code, and supply chain

- [ ] Keep custom add-ons in version control and review each module's source and license.
- [ ] Pin Python and system dependencies; test dependency upgrades before production.
- [ ] Scan images and dependencies for known vulnerabilities.
- [ ] Restrict who can deploy code and who can access production data.
- [ ] Do not install unreviewed marketplace modules directly into the production database.
- [ ] Maintain a staging database and validate module upgrades against a recent production copy.

## 7. Monitoring and operations

- [ ] Centralize Odoo, PostgreSQL, and reverse-proxy logs with retention and access controls.
- [ ] Monitor service health, HTTP 5xx rates, worker restarts, cron failures, DB connections,
      slow queries, CPU, RAM, disk, and filestore growth.
- [ ] Configure alerts with named responders and an escalation path.
- [ ] Document routine upgrade, rollback, credential rotation, backup, and restore procedures.
- [ ] Perform a security review before enabling external access.

## Launch acceptance gates

Do not call the system production-ready until all of these are demonstrated on the target host:

1. Clean deployment from a pinned revision with no manual edits to tracked source.
2. Database creation/import, user login, role permissions, and business-critical workflows.
3. Attachments and PDF reports work and survive a restart.
4. Email, scheduled jobs, and all required integrations work.
5. TLS, reverse-proxy websocket routing, database filtering, and database isolation are verified.
6. A recent backup has been restored successfully to a separate environment.
7. Monitoring and alerting are active, and rollback has been rehearsed.
