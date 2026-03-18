## MODIFIED Requirements

### Requirement: Updated endpoint request validation produces richer schema
The system MUST translate common Laravel FormRequest validation rules into OpenAPI requestBody schema for confirmed endpoints.

#### Scenario: Array-style validation rules are used
- **WHEN** a FormRequest defines a field using array-style rules
- **THEN** the generated requestBody MUST still include that field in schema and required lists when applicable

#### Scenario: Password and comparison rules are used
- **WHEN** a FormRequest includes `Password::min(...)`, `regex`, or `same:<field>`
- **THEN** the generated requestBody MUST preserve the field
- **AND** MUST reflect any reliably mappable constraints
- **AND** MUST NOT silently drop the field from the schema
