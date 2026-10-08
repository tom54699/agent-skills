---
name: docker-server-deploy
description: Use when the user wants to deploy a project to a Linux server with Docker Compose, a container registry, and CI/CD; set up or change a deployment pipeline; roll back; or troubleshoot a failed deployment. Covers environment inventory, shared services, a release-based deploy script with locking and automatic rollback, Nginx and HTTPS, GitHub Actions, and verification. Chinese triggers include 部署到 server、設定 CI/CD、上線、docker compose 部署、回滾、部署失敗、加一個服務、換網域.
metadata:
  version: "1.0.0"
---

# Docker Server Deploy

Use this skill to deploy projects to a self-managed Linux server: CI builds pinned images, pushes them to a registry, and runs a release-based `deploy.sh` that starts them with Docker Compose behind the server's reverse proxy.

## Core Rules

- Use Traditional Chinese with the user and in deployment documents.
- Read the project's collaboration rules (`AGENTS.md`, `CLAUDE.md`), existing deployment files, and change records first. Follow the project's process (for example OpenSpec) and do not create duplicate changes.
- Templates and references are defaults, not mandates. Inventory the environment and get confirmation before building.
- Prepare and validate locally first; operate on the server only within the authorization scope.
- Never hardcode one project's domain, host, path, version, CPU architecture, or resource limits into generic rules or committed files.

## Authorization Scope

- Ask before the first SSH connection in a task.
- Once the user allows the connection, read-only inventory (`docker ps`, reading configs, disk usage) needs no further confirmation.
- Change the server only as part of a plan the user confirmed. Anything outside the plan needs its own confirmation.
- Always confirm separately: deleting data, volumes, or images; changing firewall rules; changing shared services (reverse proxy, database, cache); anything that affects other projects.

## Sensitive Values and the Deployment Record

- Committed files contain no domains, hosts, users, or server paths. Server values live in `<DEPLOY_ROOT>/shared/.env` (mode `600`); CI values live in GitHub Secrets and Variables.
- Set secrets without echoing them, for example `gh secret set DEPLOY_SSH_KEY < key_file`. Never print secret values, never commit `.env`.
- Keep the deployment record in `deploy/DEPLOYMENT.local.md` and list it in `.gitignore`. If it must be shared through git, encrypt it with SOPS + age first. See `references/deployment-record.md`.

## Mode Selection

1. **Initial Setup** - the project is deployed for the first time.
2. **Deployment Change** - add a service, change the domain, change CI/CD, move servers.
3. **Operations and Troubleshooting** - manual rollback, investigate a failure, read logs.

Once CI/CD is set up, routine deployment is a push to `main`; this skill is not needed for it. If the mode is unclear, ask one short question.

## Initial Setup

1. **Inventory** (ask before connecting):
   - SSH user and key, OS, CPU architecture, CPU / RAM, disk
   - existing containers, Compose projects, networks, volumes, published ports
   - reverse proxy, certificates, cron jobs or timers, existing CI/CD
   - which services are shared with other projects (database, cache, reverse proxy)
2. **Plan**: present a Deployment Plan (see Output Shapes) and wait for confirmation.
3. **Create deployment files** from `assets/templates/`:
   - `deploy/deploy.sh`, `deploy/docker-compose.yml`, `deploy/.env.example`, `deploy/nginx.conf.template`, `deploy/nginx-bootstrap.conf.template`, `.github/workflows/deploy.yml`
   - replace placeholders (`__PROJECT__`, `__OWNER__`), services, ports, health paths, migration command, runner and platform; set `APP_SERVICES` and `MIGRATE_SERVICE` in `deploy.sh`
   - add `deploy/DEPLOYMENT.local.md` to `.gitignore`
4. **Validate locally**: `bash -n deploy/deploy.sh`, `docker compose config` with a sample env file, build the images for the server architecture, run the project tests.
5. **Prepare the server** (confirmed plan only): deployment root with `releases/` and `shared/`, `shared/.env` with mode `600`, Docker networks for shared services, a dedicated database and user for the project.
6. **Reverse proxy and HTTPS**: check DNS, get the first certificate with the bootstrap block (`references/first-certificate.md`), install the full server block, run `nginx -t` before every reload, verify renewal with a dry run. Check cloud security rules and the host firewall separately; never flush existing rules.
7. **CI/CD**: dedicated deploy key, `DEPLOY_KNOWN_HOSTS` from a verified host fingerprint, secrets via `gh secret set`, read-only registry access on the server for private images, then set the repository variable `DEPLOY_ENABLED=true`.
8. **First deployment** through CI, then run Acceptance.
9. **Write the deployment record**.

## Deployment Change

1. Read the deployment record and the current deployment files.
2. Present a Change Plan (see Output Shapes) and wait for confirmation.
3. Apply, validate locally, deploy, run Acceptance, update the deployment record.

## Operations and Troubleshooting

- Read the deployment record first. Do only what the user asked for.
- Manual rollback: `<DEPLOY_ROOT>/current/deploy.sh rollback`. It does not run migrations and does not roll back the database.
- Investigate read-only first: deployment logs in `<DEPLOY_ROOT>/shared/logs/`, `docker compose -p <project> ps` and `logs`, the CI run log.

## Deploy Script

`assets/templates/deploy.sh` (bash 3.2 compatible):

```
<DEPLOY_ROOT>/releases/<sha-commit>/   CI uploads each release to a new directory
<DEPLOY_ROOT>/current, previous        symlinks to releases
<DEPLOY_ROOT>/shared/                  .env, logs, backups; uploads never touch it
```

1. take the deployment lock (exit `75` if another deployment holds it past `LOCK_WAIT`; stale locks are removed)
2. check `shared/.env` and the Compose config
3. pull the release images; on failure stop with nothing changed
4. run the one-off migration service; on failure stop with services untouched
5. point `current` at the release and start it
6. wait until every `APP_SERVICES` container is healthy and runs this tag, and `HEALTH_URL` responds when set
7. success: update `previous`, prune old releases; failure: switch back to the previous release automatically (exit `1`), or exit `2` if that also fails

Every application image uses the same `sha-<commit>` tag. The database is never rolled back.

## Rules by Area

**Docker build**
- Use only the needed build context, whitelist `COPY`, and a `.dockerignore` that excludes secrets, `.env`, keys, and unrelated directories.
- Build for the server architecture only, unless multi-architecture is actually needed.
- Multi-stage builds; the final image keeps only runtime files and runs as a non-root user. Keep dependency layers cacheable.
- The application CMD does not run migrations.

**Compose and shared services**
- Fixed `name:` so all release directories share one Compose project.
- Persistent data uses named volumes with fixed names, or absolute paths under `shared/`. Recreating or updating containers must never delete data volumes.
- Publish ports on `127.0.0.1` only. Databases and internal services are never exposed; use SSH tunnels for admin tools.
- Shared PostgreSQL / Redis are managed outside the project's deployment directory; each project gets its own database and user, and its own Redis key prefix. See `references/optional-modules.md`.

**CI/CD**
- Checks and tests pass before images are built; deployment runs only after a successful build on `main`.
- Each image has its own build cache; push `latest` and `sha-<commit>`; deploy by `sha-<commit>`.
- Deployments queue (`cancel-in-progress: false`); the server-side lock covers manual runs.
- Use least-privilege tokens; verify the host key; never print secrets.
- Confirm action and image versions against the target environment instead of copying the template's versions.

**Migrations and rollback** - see `references/migrations-and-rollback.md`. Keep migrations backward compatible. If a deployment includes a destructive migration (dropping or changing columns or data), tell the user before deploying and recommend a backup.

**Acceptance**
- `docker compose config` is valid; containers are healthy and run the new tag.
- API, frontend, and the public HTTPS URL respond.
- Data persists across a redeploy; scheduled jobs still run.
- Internal ports are not reachable from outside.
- Record `docker stats`, disk usage, and relevant logs in the result.

**Maintenance**
- Configure container log rotation, backups, and retention.
- Before cleaning up, distinguish images, build cache, logs, volumes, and business data. Remove specific tags only; never run a global prune without confirmation.
- Evaluate a monitoring tool's own CPU / RAM cost and notification channel before adding it.
- Compare performance changes under the same load: latency, CPU, RAM, disk.

## Templates

| File | Purpose |
|---|---|
| `assets/templates/deploy.sh` | release-based deployment, lock, migration, health check, rollback |
| `assets/templates/docker-compose.yml` | pinned images, migration job, named volume, internal network, health checks |
| `assets/templates/github-workflow.yml` | test → build per image → serialized deployment |
| `assets/templates/nginx.conf.template` | HTTPS reverse proxy for frontend and API, rendered with `envsubst` on the server |
| `assets/templates/nginx-bootstrap.conf.template` | HTTP-only block for the first certificate |
| `assets/templates/env.example` | server `.env` example with fake values |

## References

| File | Read when |
|---|---|
| `references/first-certificate.md` | getting the first TLS certificate |
| `references/migrations-and-rollback.md` | the project has a database, or a rollback is needed |
| `references/optional-modules.md` | shared PostgreSQL, Redis, vector database, post-deploy jobs, monitoring |
| `references/oracle-cloud.md` | the server runs on Oracle Cloud |
| `references/deployment-record.md` | writing or reading the deployment record |
| `references/reference-project.md` | comparing with the reference project the templates came from |

## Output Shapes

### Deployment Plan

```markdown
## Deployment Plan

Generated-by: docker-server-deploy v1.0.0
Mode: <initial setup / deployment change>

Environment:
- Server: <OS / CPU architecture / RAM / disk>
- Reverse proxy: <existing Nginx / other / none>
- Shared services: <reuse / create / none>
- Registry and CI/CD: <GHCR + GitHub Actions / other>

Changes:
| Where | Change | Affects other projects |
|---|---|---|

Server operations needing confirmation:
- <operation>

Migration: <none / backward compatible / destructive - backup plan>
Rollback: <previous release / notes>
```

### Deployment Result

```markdown
## Deployment Result

Generated-by: docker-server-deploy v1.0.0
Release: <sha-commit>
Result: <success / failed, nothing changed / rolled back to sha-... / rollback failed>

Acceptance:
- <check>: <pass / fail>

Limits and follow-ups:
- <item>

Deployment record updated: <yes / no>
```
