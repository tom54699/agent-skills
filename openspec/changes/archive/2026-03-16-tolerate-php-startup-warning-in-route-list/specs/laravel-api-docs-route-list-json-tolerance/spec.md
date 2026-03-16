## ADDED Requirements

### Requirement: Route list JSON parsing MUST tolerate non-JSON prefix output
The system MUST discard leading non-JSON output before decoding the result of `php -n artisan route:list --json`.

#### Scenario: Startup warning appears before JSON
- **WHEN** the Laravel route list command prints PHP startup warnings before the actual JSON payload
- **THEN** the candidate analyzer and OpenAPI generator MUST trim the prefix before JSON decoding
- **AND** the guided-sync flow MUST continue as long as the remaining payload is valid JSON
