## MODIFIED Requirements

### Requirement: Guided sync SHALL update OpenAPI through the maintained generator path
The system MUST update `docs/api-docs/openapi.yaml` through the maintained OpenAPI generator path, and that path MUST now be backed by the PHP generator rather than shell parser scripts.

#### Scenario: Confirmed candidates are applied
- **WHEN** the user confirms the final candidate list and OpenAPI update begins
- **THEN** guided sync invokes the maintained `gen-openapi` entrypoint
- **AND** the actual endpoint parsing and OpenAPI generation are performed by the PHP generator
- **AND** downstream Apidog and HTML steps continue to consume the resulting `openapi.yaml` without contract changes
