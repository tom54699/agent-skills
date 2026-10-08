## ADDED Requirements

### Requirement: Docker Server Deploy Skill
The repository SHALL provide a `docker-server-deploy` skill that deploys projects to a Linux server with Docker Compose, a container registry, and CI/CD.

#### Scenario: Skill exists in active skills
- **WHEN** a user wants to deploy a project to a server, set up CI/CD, change a deployment, roll back, or troubleshoot a deployment
- **THEN** the skill MUST exist under `skills/docker-server-deploy/`
- **AND** the skill MUST include a `SKILL.md` entrypoint, templates under `assets/templates/`, and references under `references/`

#### Scenario: Project rules come first
- **WHEN** the skill starts working in a project
- **THEN** it MUST read the project's collaboration rules, existing deployment files, and change records first
- **AND** it MUST follow the project's required process, such as OpenSpec, without creating duplicate changes

### Requirement: Deployment modes
The skill SHALL distinguish initial setup, deployment changes, and operations.

#### Scenario: Initial setup
- **WHEN** a project is deployed for the first time
- **THEN** the skill MUST inventory the environment, present a deployment plan, get confirmation, create deployment files from the templates, prepare the server, run the first deployment, verify it, and write the deployment record

#### Scenario: Deployment change
- **WHEN** the user wants to change an existing deployment
- **THEN** the skill MUST read the deployment record first, present a change plan, and get confirmation before changing anything

#### Scenario: Operations and troubleshooting
- **WHEN** the user asks to roll back, investigate a failure, or read logs
- **THEN** the skill MUST read the deployment record first
- **AND** it MUST perform only the operations the user asked for

### Requirement: Server authorization scope
The skill SHALL operate on servers only within an explicitly confirmed scope.

#### Scenario: First connection
- **WHEN** the skill needs to connect to a server over SSH for the first time in a task
- **THEN** it MUST ask the user before connecting

#### Scenario: Read-only inventory
- **WHEN** the user has allowed the connection
- **THEN** the skill MAY run read-only inventory commands without further confirmation

#### Scenario: Changes follow the confirmed plan
- **WHEN** the skill changes anything on a server
- **THEN** the change MUST be part of a plan the user confirmed
- **AND** any change outside that plan MUST be confirmed separately

#### Scenario: High-impact operations
- **WHEN** an operation deletes data, volumes, or images, changes firewall rules, changes shared services such as a shared reverse proxy, database, or cache, or affects other projects
- **THEN** the skill MUST get explicit confirmation for that operation

### Requirement: Deployment record and sensitive values
The skill SHALL keep deployment records and environment-specific values out of git unless encrypted.

#### Scenario: Deployment record location
- **WHEN** the skill writes the deployment record
- **THEN** it MUST write it to a local file listed in `.gitignore`
- **AND** if the user wants to share it through git, it MUST be encrypted with SOPS and age before committing

#### Scenario: Environment-specific values
- **WHEN** the skill creates deployment files in the repository
- **THEN** domains, hosts, users, and server paths MUST NOT be written into committed files
- **AND** they MUST come from the server's shared environment file or from CI secrets and variables

#### Scenario: Secret handling
- **WHEN** the skill sets or uses secrets
- **THEN** secret values MUST NOT appear in conversation output, logs, or committed files
- **AND** the server environment file MUST have permission `600`

### Requirement: Deployment templates
The skill SHALL provide parameterized templates for CI/CD, deployment, Compose, and the reverse proxy.

#### Scenario: Template set
- **WHEN** an agent reads `assets/templates/`
- **THEN** it MUST find a GitHub Actions workflow, `deploy.sh`, `docker-compose.yml`, an Nginx server block, an HTTP-only Nginx bootstrap block for the first certificate, and `.env.example`

#### Scenario: Project-specific values are parameters
- **WHEN** a template contains project-specific values
- **THEN** they MUST be placeholders or documented examples, not values from any real project

#### Scenario: Versions need confirmation
- **WHEN** a template pins an action or image version
- **THEN** it MUST note that the version is to be confirmed against the target environment

### Requirement: Release-based deployment script
The `deploy.sh` template SHALL deploy pinned releases from separate release directories with locking, migration, verification, and rollback.

#### Scenario: Release layout
- **WHEN** CI uploads deployment files
- **THEN** it MUST upload them to a new `releases/<tag>/` directory under the deployment root
- **AND** `shared/` MUST hold the environment file, logs, and backups so uploads never touch it

#### Scenario: Pinned version
- **WHEN** `deploy.sh` deploys a release
- **THEN** every application image MUST use the release tag `sha-<commit>`, the same tag for all application services

#### Scenario: Deployment lock
- **WHEN** another deployment holds the lock
- **THEN** `deploy.sh` MUST wait up to the configured limit and then exit with code 75 without changing anything
- **AND** a lock left by a process that no longer exists MUST be removed and the deployment MUST continue

#### Scenario: Pull failure
- **WHEN** pulling the release images fails
- **THEN** `deploy.sh` MUST exit with a failure without switching releases or touching running services

#### Scenario: Migration failure
- **WHEN** the one-off migration job fails
- **THEN** `deploy.sh` MUST exit with a failure without switching releases or touching running services
- **AND** it MUST report that the database may be partially migrated

#### Scenario: Health verification
- **WHEN** the new release has been started
- **THEN** `deploy.sh` MUST verify within the timeout that each application service container is healthy, or running when it has no health check, that it runs the release tag, and that the external health URL responds when one is configured

#### Scenario: Automatic rollback
- **WHEN** starting or verifying the new release fails and a previous release exists
- **THEN** `deploy.sh` MUST switch back to the previous release, start it, verify it, and exit with code 1
- **AND** if the rollback verification also fails, it MUST exit with code 2
- **AND** it MUST NOT roll back the database

#### Scenario: Manual rollback
- **WHEN** the user runs `deploy.sh rollback`
- **THEN** it MUST swap the current and previous releases under the lock, start the target release without running migrations, and verify it

#### Scenario: Release cleanup
- **WHEN** a deployment succeeds
- **THEN** `deploy.sh` MUST keep the current release, the previous release, and the most recently attempted releases up to the configured count
- **AND** it MUST remove only other releases that were previously attempted
- **AND** it MUST NOT remove release directories that have never been deployed

### Requirement: CI/CD behavior
The workflow template SHALL test, build pinned images, and deploy serially.

#### Scenario: Build
- **WHEN** the workflow runs on the main branch
- **THEN** it MUST run the project checks before building
- **AND** it MUST build each image separately with its own build cache and push both `latest` and `sha-<commit>` tags

#### Scenario: Serialized deployment
- **WHEN** a deployment job is running
- **THEN** a newer workflow run MUST NOT cancel it

#### Scenario: Deployment not enabled
- **WHEN** the repository variable `DEPLOY_ENABLED` is not `true`
- **THEN** the workflow MUST skip deployment and report that CD is not enabled

#### Scenario: Deployment misconfigured
- **WHEN** `DEPLOY_ENABLED` is `true` but a required deployment secret is missing
- **THEN** the deployment job MUST fail

#### Scenario: Host verification
- **WHEN** the workflow connects to the server
- **THEN** it MUST verify the host against a pre-verified known hosts secret instead of trusting a key scanned during the run

### Requirement: Migrations and rollback guidance
The skill SHALL treat database migrations as a separate deployment step and explain rollback limits.

#### Scenario: Migration step
- **WHEN** the skill sets up a project with database migrations
- **THEN** it MUST define a one-off migration service that uses the application image
- **AND** the application container MUST NOT run migrations on startup

#### Scenario: Destructive migration
- **WHEN** a deployment includes a migration that drops or changes existing columns or data
- **THEN** the skill MUST tell the user before deploying and recommend a backup

### Requirement: Deployment script tests
The repository SHALL test the `deploy.sh` template.

#### Scenario: Simulated tests
- **WHEN** `tests/docker-server-deploy/run-tests.sh` runs
- **THEN** it MUST cover successful deployment, pull failure, migration failure, health timeout with rollback, manual rollback, a held lock, and a stale lock using simulated `docker` and `curl` commands
- **AND** it MUST NOT require Docker

#### Scenario: Integration test
- **WHEN** `tests/docker-server-deploy/integration-test.sh` runs with a Docker daemon available
- **THEN** it MUST exercise successful deployment, pull failure, migration failure, rollback after a failed health check, and manual rollback with real containers
