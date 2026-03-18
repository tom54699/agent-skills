# laravel-api-docs-redoc-extra-content Specification

## Purpose
TBD - created by archiving change align-laravel-api-docs-runtime-and-tail-steps. Update Purpose after archive.
## Requirements
### Requirement: Redoc generation can optionally render extra markdown content
The system MUST allow guided-sync to include `docs/api-docs/redoc/extra.md` in the generated HTML without mutating `docs/api-docs/openapi.yaml`.

#### Scenario: User does not request extra content
- **WHEN** `gen-html.sh` runs without enabling extra markdown
- **THEN** the generated HTML MUST contain the Redoc document only
- **AND** the OpenAPI file MUST remain unchanged

#### Scenario: User requests extra content and file exists
- **WHEN** `gen-html.sh` runs with extra markdown enabled and `docs/api-docs/redoc/extra.md` exists
- **THEN** the generated HTML MUST render the markdown content in a predictable extra section
- **AND** the OpenAPI file MUST remain unchanged

#### Scenario: User requests extra content but file is missing
- **WHEN** `gen-html.sh` runs with extra markdown enabled and `docs/api-docs/redoc/extra.md` does not exist
- **THEN** the script MUST fail with a clear error
- **AND** it MUST not generate a partial HTML file

