## MODIFIED Requirements

### Requirement: Updated endpoint request validation produces richer schema
The system MUST translate common Laravel FormRequest validation rules for confirmed endpoints into the appropriate OpenAPI request input structure based on HTTP method.

#### Scenario: Body method generates requestBody
- **WHEN** a confirmed endpoint uses a body method such as POST, PUT, or PATCH
- **THEN** the generated OpenAPI operation MUST place mapped validation fields under `requestBody`

#### Scenario: Non-body method generates parameters
- **WHEN** a confirmed endpoint uses a non-body method such as GET
- **THEN** the generated OpenAPI operation MUST place mapped validation fields under `parameters`
- **AND** MUST NOT emit those fields only as `requestBody`

#### Scenario: Array-style validation rules are used
- **WHEN** a FormRequest defines a field using array-style rules
- **THEN** the generated request input MUST still include that field in schema and required lists when applicable

#### Scenario: Password and comparison rules are used
- **WHEN** a FormRequest includes `Password::min(...)`, `regex`, or `same:<field>`
- **THEN** the generated request input MUST preserve the field
- **AND** MUST reflect any reliably mappable constraints
- **AND** MUST NOT silently drop the field from the generated OpenAPI input
