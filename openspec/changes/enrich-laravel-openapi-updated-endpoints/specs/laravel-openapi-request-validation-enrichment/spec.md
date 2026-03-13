## ADDED Requirements

### Requirement: Updated endpoints MUST expose richer request validation schema
The system MUST enrich requestBody schema for updated endpoints by mapping common Laravel FormRequest validation rules into OpenAPI schema keywords.

#### Scenario: Common scalar validation rules are present
- **WHEN** an updated endpoint uses a FormRequest with common rules such as `required`, `nullable`, `string`, `integer`, `numeric`, `boolean`, `email`, `date`, `min`, `max`, `between`, `size`, `digits`, or `in`
- **THEN** the generated OpenAPI requestBody schema MUST reflect the supported rule semantics with appropriate OpenAPI keywords

#### Scenario: Unsupported or dynamic rules are present
- **WHEN** a FormRequest contains rules the generator does not support or cannot safely resolve
- **THEN** the generator MUST keep the field in the schema when possible
- **AND** it MUST fall back to conservative output rather than inventing inaccurate constraints

### Requirement: Updated endpoints MUST include request examples
The system MUST generate a requestBody example for updated endpoints when requestBody is present.

#### Scenario: Scalar fields are present
- **WHEN** an updated endpoint has scalar request fields
- **THEN** the request example MUST include deterministic example values matching field type, format, or enum

#### Scenario: Array fields are present
- **WHEN** an updated endpoint has array request fields
- **THEN** the request example MUST include an array-shaped example value
