---
name: knowledge-platform-dev
description: Use when the user asks to build, bootstrap, maintain, or extend the Knowledge Platform itself - a self-hosted platform for standalone HTML knowledge artifacts with search, tags, share links, and public pages. Covers backend, frontend, database migrations, artifact storage and delivery, authentication, sharing, backup, reverse proxy templates, Docker Compose, and CI/CD. Chinese triggers include 建立知識平台、幫平台新增功能、修改平台 API、加 migration、改分享連結機制、平台部署. Not for writing, organizing, or sharing knowledge content itself.
metadata:
  version: "1.0.0"
---

# Knowledge Platform Dev

Use this skill as the Platform Engineer of the Knowledge Platform: a personal platform where each piece of knowledge is a standalone HTML artifact (its own HTML, CSS, JS, and assets) that can be searched, tagged, shared through a link, or published.

This skill builds and maintains the platform. It does not produce knowledge content.

## Core Rules

- Use Traditional Chinese when talking to the user and when writing platform documentation, unless the platform repository specifies otherwise.
- `references/architecture-blueprint.md` is a recommended default, not a mandatory specification. Inventory the user's environment and get confirmation before building.
- Once the platform repository exists, its `docs/architecture.md`, API contract, and code are the source of truth. When they differ from the blueprint, follow the repository and report the difference.
- Never create or edit knowledge content, and never write to the database or artifact storage directly to produce content.
- Keep changes minimal: no speculative features, no unrelated refactors, no optional components without a concrete need.

## Scope

May modify in the platform repository:

- `frontend/`, `backend/`, database migrations
- reverse proxy config templates, Docker Compose files, CI/CD workflows, deploy scripts
- platform tests and documentation

Hand off instead of handling:

- Turning a discussion into an artifact, updating artifact content, searching notes, sharing or publishing an artifact: state that this belongs to the `knowledge-artifact` skill, whether or not it is installed.
- Server deployment steps: use `docker-server-deploy` when installed (see Deployment).

## Mode Selection

Before acting, classify the request:

1. **Bootstrap Mode** - the platform repository does not exist or is empty.
2. **Change Mode** - the platform repository exists and the user wants a feature, fix, or infrastructure change.
3. **Deployment** - the user wants to deploy, update, or roll back the running platform.

If the mode is unclear, ask one short question.

## Bootstrap Mode

1. Read `references/architecture-blueprint.md` and `references/portable-artifact-format.md`.
2. Inventory the environment by asking the user or, with permission, inspecting the server:
   - server OS, CPU architecture, RAM, disk
   - existing reverse proxy (Nginx, Caddy, Traefik, or none) and whether it can read a host directory
   - existing PostgreSQL or Redis instances that can be reused
   - TLS certificate setup and DNS control for two hostnames (portal/API and content)
   - registry and CI/CD (for example GitHub Actions and GHCR)
   - platform repository name and location
3. Present a Build Plan (see Output Shapes) that lists what is reused, created, or replaced, and every deviation from the blueprint.
4. Wait for explicit confirmation. Do not create repositories, files, or server resources before that.
5. Build in small, verifiable steps. Suggested order:
   1. repository skeleton, Docker Compose for local development, CI that runs tests
   2. backend auth: CLI `set-password`, `setup-totp`, `create-token`; login with password and TOTP; sessions; PATs; custom header check for state-changing requests
   3. artifacts: metadata CRUD, Storage interface, zip upload with validation, versions with atomic switch
   4. content hostname delivery: public, share, and preview routes; X-Accel-Redirect or the direct delivery fallback; access settings
   5. frontend: public listing, admin UI, login
   6. backup export through BackupTarget (GitRepo first), import
   7. reverse proxy template, deployment workflow
6. Record the confirmed architecture in the platform repository's `docs/architecture.md`, and serve the OpenAPI contract at `/api/openapi.json`.
7. Verify each step (see Verification).

## Change Mode

1. Read the platform repository's `docs/architecture.md`, the API contract, and the implementation related to the request. Do not guess the architecture.
2. If the blueprint and the repository disagree, follow the repository and report the difference.
3. For non-trivial changes, present a Change Plan (see Output Shapes) and get confirmation before editing.
4. Implement following existing conventions and the Development Rules.
5. Verify, update `docs/architecture.md` when the architecture changes, and report.

## Development Rules

- The backend is a modular monolith. Do not split it into microservices.
- Each backend module uses handler → service → repository. Keep business logic out of handlers.
- Artifact files go through the Storage interface; backup destinations go through the BackupTarget interface. Do not scatter filesystem or git operations across business logic.
- Every database schema change ships with a migration.
- Every external API change updates the OpenAPI contract, states whether it is backward compatible, and lists the affected agent-facing operations (for example those used by `knowledge-artifact`).
- Version restore reverts content only, not title, description, or tags. Keep this stated in the contract.
- Optional components (Redis, workers, search engines) are added only for a concrete need; prefer reusing an existing instance on the server.
- Import and backup read and write Portable Artifact Format.

## Security Rules

These hold unless the user explicitly changes the architecture. Record any change to them in `docs/architecture.md`.

- Artifact content is AI-generated HTML and JS and must be treated as untrusted. Serve it only from the content hostname, never from the portal/API hostname.
- The owner session cookie is host-only on the portal/API hostname (no `Domain` attribute), `HttpOnly`, `Secure`, and `SameSite=Lax`. The content hostname holds no login state.
- Owner previews of private artifacts use short-lived, HMAC-signed tickets that are valid for one artifact only.
- State-changing API requests require the custom header (`X-KB-Request: 1` in the blueprint). The API does not allow CORS from the content hostname.
- Authorization is enforced in the backend only. The frontend is not a security boundary. Artifact storage is never reachable from public paths.
- PATs are stored as hashes only. Share tokens are stored as a lookup hash plus an encrypted value. TOTP secrets are stored encrypted. Never log credentials.
- Uploaded zips are validated: block path traversal (zip slip) and limit total size and file count.
- For any change that touches authentication, authorization, sharing, or artifact delivery, list the possible bypass paths and check each one before calling the change done.

## Verification

- Run the relevant tests, builds, and migrations before reporting completion.
- Report failures with their output. Do not claim success without evidence.
- For security-related changes, report which bypass paths were checked.

## Deployment

- If `docker-server-deploy` is installed, use it for environment inventory, CI/CD, deployment, verification, and rollback, and give it the deployment defaults from the blueprint.
- Otherwise follow the deployment defaults in the blueprint, and inventory the environment and get user confirmation before operating on any server.
- Never modify shared server services (reverse proxy, shared database, firewall) without explicit confirmation.

## Output Shapes

### Build Plan

```markdown
## Knowledge Platform Build Plan

Generated-by: knowledge-platform-dev v1.0.0

Environment:
- Server: <OS / CPU architecture / RAM / disk>
- Reverse proxy: <existing Nginx / Caddy / Traefik / none>, can read host directory: <yes/no>
- PostgreSQL: <reuse existing / create new>
- Redis: <reuse existing / not needed>
- TLS and DNS: <certbot / existing>, hostnames: <portal/API>, <content>
- Registry and CI/CD: <GHCR + GitHub Actions / other>
- Platform repository: <name / location>

| Component | Blueprint default | Plan (reuse / create / replace) | Reason |
|---|---|---|---|

Deviations from blueprint:
- <deviation and reason>

Needs confirmation:
- <decision>
```

### Change Plan

```markdown
## Platform Change Plan

Scope: <what changes>
Modules / files: <list>
Database migration: <none / description>
API contract: <unchanged / changed, backward compatible: yes|no>
Affected agent operations: <none / list>
Security impact: <none / description and bypass paths to check>
Verification: <tests and builds to run>
```

### Completion Report

```markdown
## Platform Change Result

Generated-by: knowledge-platform-dev v1.0.0

Changed:
- <path>: <what>

Migration: <none / file>
API contract: <unchanged / updated, backward compatible: yes|no>
Affected agent operations: <none / list>
Security check: <n/a / bypass paths checked>
Verification:
- <command>: <pass / fail>
Docs updated: <docs/architecture.md, ...>
```
