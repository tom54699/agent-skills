# laravel-api-docs-runtime-readiness Specification

## Purpose
TBD - created by archiving change align-laravel-api-docs-runtime-and-tail-steps. Update Purpose after archive.
## Requirements
### Requirement: Preflight validates PHP runtime readiness
The system MUST verify that the PHP runtime required by the guided-sync main path is usable before candidate inference or OpenAPI generation starts.

#### Scenario: PHP binary is missing
- **WHEN** `preflight.sh` runs in a Laravel project without a `php` command available
- **THEN** the script MUST fail in Step 1
- **AND** the error output MUST explicitly state that PHP is required for the PHP-based analyzer/generator path

#### Scenario: `php -n` cannot execute
- **WHEN** `preflight.sh` runs and `php -n -r 'echo 1;'` fails
- **THEN** the script MUST fail in Step 1
- **AND** the error output MUST indicate that the clean PHP runtime path is not available

#### Scenario: Laravel route snapshot cannot run under `php -n`
- **WHEN** `preflight.sh` runs and `php -n artisan route:list --json` fails or produces invalid JSON
- **THEN** the script MUST fail in Step 1
- **AND** the error output MUST indicate that Laravel route listing is not ready for guided-sync

#### Scenario: PHP runtime is ready
- **WHEN** `preflight.sh` runs and `php`, `php -n`, and `php -n artisan route:list --json` all succeed
- **THEN** the script MUST include those checks in its structured result
- **AND** guided-sync MAY continue to Step 2

