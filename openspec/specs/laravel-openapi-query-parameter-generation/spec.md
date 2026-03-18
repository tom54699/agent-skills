# laravel-openapi-query-parameter-generation Specification

## Purpose
Define how non-body request validation rules are emitted as OpenAPI query parameters.

## Requirements
### Requirement: Non-body request validation MUST generate OpenAPI query parameters
The system MUST translate validation rules from confirmed non-body endpoints into OpenAPI `parameters` with `in: query`.

#### Scenario: GET FormRequest generates query parameters
- **WHEN** a confirmed GET endpoint uses a FormRequest with validation rules
- **THEN** the generated OpenAPI operation MUST include `parameters`
- **AND** each mappable field MUST be emitted with `in: query`

#### Scenario: GET inline validation generates query parameters
- **WHEN** a confirmed GET endpoint uses inline validation such as `$request->validate([...])` or `Validator::make(...)`
- **THEN** the generated OpenAPI operation MUST include query `parameters` derived from those rules

### Requirement: Query parameter schema MUST preserve mappable validation metadata
The system MUST preserve reliably mappable validation metadata when generating query parameters.

#### Scenario: Required query field is marked required
- **WHEN** a GET validation field is required
- **THEN** the generated query parameter MUST set `required: true`

#### Scenario: Typed query field preserves schema keywords
- **WHEN** a GET validation field has reliably mappable type or constraints
- **THEN** the generated query parameter schema MUST preserve those keywords
