## MODIFIED Requirements

### Requirement: Generated OpenAPI security requirements match route middleware
The system MUST mark bearer token requirements at operation level according to route middleware instead of applying global bearer security to every endpoint.

#### Scenario: Public endpoint has no auth middleware
- **WHEN** a route has no authentication middleware
- **THEN** the generated operation MUST NOT include bearerAuth security

#### Scenario: Protected endpoint has auth middleware
- **WHEN** a route includes authentication middleware such as `auth`, `auth:*`, `auth:sanctum`, `auth:api`, or project JWT middleware
- **THEN** the generated operation MUST include bearerAuth security
