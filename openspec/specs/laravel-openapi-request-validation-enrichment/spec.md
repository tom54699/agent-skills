# laravel-openapi-request-validation-enrichment Specification

## Purpose
Define how Laravel request validation rules are translated into richer OpenAPI request input for confirmed endpoints.

## Requirements
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

### Requirement: Updated endpoints MUST expose richer request validation schema
The system MUST enrich confirmed endpoint request input by mapping common Laravel validation rules into OpenAPI schema keywords, regardless of whether the rules come from FormRequest or inline controller validation.

#### Scenario: Common scalar validation rules are present
- **WHEN** a confirmed endpoint uses a FormRequest with common rules such as `required`, `nullable`, `string`, `integer`, `numeric`, `boolean`, `email`, `date`, `min`, `max`, `between`, `size`, `digits`, or `in`
- **THEN** the generated OpenAPI request input MUST reflect the supported rule semantics with appropriate OpenAPI keywords

#### Scenario: Inline validation rules are present in the controller action
- **WHEN** a confirmed endpoint validates request data through `$request->validate([...])` or `Validator::make(..., [...])`
- **THEN** the generated OpenAPI request input MUST reflect the supported rule semantics from that inline validation block
- **AND** it MUST NOT fall back to an empty object schema merely because no FormRequest class is present

#### Scenario: Unsupported or dynamic rules are present
- **WHEN** a FormRequest or inline validation block contains rules the generator does not support or cannot safely resolve
- **THEN** the generator MUST keep the field in the schema when possible
- **AND** it MUST fall back to conservative output rather than inventing inaccurate constraints

### Requirement: Updated endpoints MUST include request examples
The system MUST generate request examples for confirmed endpoints when request input is present.

#### Scenario: Scalar fields are present
- **WHEN** an endpoint has scalar request fields
- **THEN** the request example MUST include deterministic example values matching field type, format, or enum

#### Scenario: Array fields are present
- **WHEN** an endpoint has array request fields
- **THEN** the request example MUST include an array-shaped example value
