## ADDED Requirements

### Requirement: Knowledge Platform Dev Skill
The repository SHALL provide a `knowledge-platform-dev` skill that guides an AI agent acting as the Platform Engineer for the Knowledge Platform.

#### Scenario: Skill exists in active skills
- **WHEN** a user wants to build, maintain, or extend the Knowledge Platform itself
- **THEN** the skill MUST exist under `skills/knowledge-platform-dev/`
- **AND** the skill MUST include a `SKILL.md` entrypoint
- **AND** the skill MUST include `references/architecture-blueprint.md` and `references/portable-artifact-format.md`

#### Scenario: Skill output language
- **WHEN** the skill communicates with the user or writes platform documentation
- **THEN** it MUST use Traditional Chinese unless the target platform repository specifies otherwise

### Requirement: Platform responsibility boundary
The skill SHALL limit its scope to building and maintaining the platform, and MUST hand off knowledge content work to `knowledge-artifact`.

#### Scenario: Platform change is requested
- **WHEN** the user asks to change platform features, backend, frontend, database schema, reverse proxy templates, Docker Compose, CI/CD, tests, or platform documentation
- **THEN** the skill MAY modify those parts of the platform repository

#### Scenario: Knowledge content is requested
- **WHEN** the user asks to turn a discussion into an artifact, update an artifact's content, or share an artifact
- **THEN** the skill MUST NOT handle the request itself
- **AND** it MUST state that the request belongs to the `knowledge-artifact` skill, whether or not that skill is installed

#### Scenario: Platform data is not edited directly
- **WHEN** the skill works on the platform
- **THEN** it MUST NOT create or edit knowledge content by writing directly to the database or artifact storage

### Requirement: Blueprint is a recommended default
The skill SHALL treat the architecture blueprint as a recommended default, not a mandatory specification.

#### Scenario: Bootstrapping a new platform
- **WHEN** the platform repository does not exist or is empty
- **THEN** the skill MUST inventory the deployment environment before building, including existing reverse proxy, PostgreSQL, Redis, TLS certificates, and server CPU architecture
- **AND** it MUST present a build plan that lists which blueprint components are reused, created, or replaced
- **AND** it MUST NOT start building until the user confirms the plan

#### Scenario: User environment differs from the blueprint
- **WHEN** the user's environment or preference conflicts with a blueprint default
- **THEN** the skill MUST present the documented alternative or ask the user, instead of forcing the default

#### Scenario: Optional components
- **WHEN** a component is marked optional in the blueprint, such as Redis
- **THEN** the skill MUST NOT add it unless a concrete need exists or the user requests it
- **AND** it MUST prefer reusing an existing instance on the server when one is available

### Requirement: Platform repository is the source of truth
After bootstrap, the skill SHALL treat the platform repository's documentation and code as the source of truth for the current architecture.

#### Scenario: Bootstrap records the architecture
- **WHEN** the skill bootstraps the platform
- **THEN** it MUST record the confirmed architecture in the platform repository's `docs/architecture.md`

#### Scenario: Changing an existing platform
- **WHEN** the platform repository already exists
- **THEN** the skill MUST read `docs/architecture.md`, the API contract, and the relevant implementation before proposing changes
- **AND** it MUST follow existing conventions instead of guessing the architecture

#### Scenario: Blueprint and repository disagree
- **WHEN** the blueprint and the platform repository disagree
- **THEN** the skill MUST follow the repository
- **AND** it MUST report the discrepancy to the user instead of silently changing the repository back to the blueprint

#### Scenario: Small request
- **WHEN** the user's request is small
- **THEN** the skill MUST NOT perform unrelated large refactors

### Requirement: Data and contract changes
The skill SHALL keep database schema and the external API contract consistent with implementation changes.

#### Scenario: Database schema changes
- **WHEN** a change modifies the database schema
- **THEN** the skill MUST add a migration

#### Scenario: External API changes
- **WHEN** a change modifies the external API
- **THEN** the skill MUST update the OpenAPI contract served at `/api/openapi.json`
- **AND** it MUST evaluate backward compatibility
- **AND** it MUST report which agent-facing operations, such as those used by `knowledge-artifact`, are affected

### Requirement: Platform security rules
The skill SHALL enforce the platform's security boundaries when building or changing the platform.

#### Scenario: Artifact content isolation
- **WHEN** the skill implements or changes artifact delivery
- **THEN** artifact content MUST be served only from the content hostname, separate from the portal and API hostname
- **AND** the owner session cookie MUST be host-only on the portal and API hostname
- **AND** the content hostname MUST NOT hold any login state
- **AND** owner previews of private artifacts MUST use short-lived, single-artifact signed tickets

#### Scenario: Cross-site request protection
- **WHEN** the skill implements state-changing API endpoints
- **THEN** those endpoints MUST require the custom header defined in the blueprint
- **AND** the API MUST NOT allow CORS from the content hostname

#### Scenario: Authorization location
- **WHEN** the skill implements access control
- **THEN** authorization MUST be enforced in the backend
- **AND** the frontend MUST NOT be treated as a security boundary
- **AND** artifact storage MUST NOT be directly reachable from public paths

#### Scenario: Credential storage
- **WHEN** the skill stores credentials
- **THEN** PATs MUST be stored only as hashes
- **AND** share tokens MUST be stored as a hash for lookup plus an encrypted value for redisplay
- **AND** TOTP secrets MUST be stored encrypted

#### Scenario: Security-related change
- **WHEN** a change affects authentication, authorization, sharing, or artifact delivery
- **THEN** the skill MUST check for bypass paths before considering the change complete

### Requirement: Verification before completion
The skill SHALL verify platform changes before reporting them as done.

#### Scenario: Change is implemented
- **WHEN** the skill finishes a platform change
- **THEN** it MUST run the relevant tests and builds
- **AND** it MUST report failures faithfully instead of claiming success

### Requirement: Deployment handoff
The skill SHALL delegate deployment to `docker-server-deploy` when that skill is available.

#### Scenario: Deployment skill is installed
- **WHEN** the user asks to deploy the platform and `docker-server-deploy` is available
- **THEN** the skill MUST use `docker-server-deploy` for environment inventory, CI/CD, deployment, verification, and rollback

#### Scenario: Deployment skill is not installed
- **WHEN** `docker-server-deploy` is not available
- **THEN** the skill MUST follow the deployment defaults in the blueprint
- **AND** it MUST inventory the environment and get user confirmation before operating on the server

### Requirement: Architecture blueprint content
The blueprint reference SHALL document the v1 platform design with defaults, alternatives, and rationale.

#### Scenario: Blueprint coverage
- **WHEN** an agent reads `references/architecture-blueprint.md`
- **THEN** it MUST find the hostnames and security boundary, components and responsibilities, access model, authentication model, URL routing, main flows, data tables, API surface, backup design, deployment defaults with fallbacks, architecture decision records, and v1 exclusions

#### Scenario: Defaults have fallbacks
- **WHEN** the blueprint defines a deployment default that depends on the environment
- **THEN** it MUST document the fallback, including direct backend delivery when X-Accel-Redirect is not available

### Requirement: Portable Artifact Format
The skill SHALL define the Portable Artifact Format and require the platform's import and backup features to use it.

#### Scenario: Format structure
- **WHEN** an artifact is stored in Portable Artifact Format
- **THEN** it MUST be a `<slug>/` directory containing `index.html` and `metadata.json`, with optional `style.css`, `script.js`, and `assets/`
- **AND** `metadata.json` MUST include `format_version`, `generated_by`, `slug`, `title`, `description`, `tags`, `visibility`, `created_at`, and `updated_at`

#### Scenario: Import and backup use the same format
- **WHEN** the skill implements platform import or backup export
- **THEN** both MUST read and write Portable Artifact Format
- **AND** backup export MUST NOT include password hashes, TOTP secrets, PATs, or sessions
