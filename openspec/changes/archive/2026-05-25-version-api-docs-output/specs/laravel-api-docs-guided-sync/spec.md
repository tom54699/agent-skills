## MODIFIED Requirements

### Requirement: Skill SHALL keep OpenAPI as sync source and HTML as derived output
The skill MUST update `docs/api-docs/openapi.yaml`, sync that file to Apidog first, then optionally generate HTML from the same OpenAPI document. When formal HTML generation runs, the skill MUST keep `docs/api-docs/redoc/` as the latest stable entry and MUST also persist a timestamped version snapshot under `docs/api-docs/versions/<version-id>/`.

#### Scenario: Regular sync flow
- **WHEN** endpoint analysis and OpenAPI update complete
- **THEN** the skill uploads `docs/api-docs/openapi.yaml` to Apidog before any HTML generation step

#### Scenario: Formal HTML generation preserves a version snapshot
- **WHEN** Apidog sync succeeds and the user chooses to generate Redoc HTML
- **THEN** the skill generates latest HTML under `docs/api-docs/redoc/`
- **AND** persists the same HTML output and current OpenAPI file under `docs/api-docs/versions/<version-id>/`
