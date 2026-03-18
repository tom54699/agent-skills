# laravel-openapi-request-schema-normalization Specification

## Purpose
Define normalization rules that turn Laravel request validation fields into nested OpenAPI request schema.

## Requirements
### Requirement: Request validation produces nested OpenAPI schema
The system MUST translate Laravel request validation fields into correctly nested OpenAPI requestBody schema instead of flattening dotted and wildcard field names.

#### Scenario: Dotted object field is used
- **WHEN** a request field is declared as `profile.name`
- **THEN** the generated requestBody schema MUST place `name` under `profile.properties`

#### Scenario: Wildcard array field is used
- **WHEN** a request field is declared as `items.*.id`
- **THEN** the generated requestBody schema MUST represent `items` as an array
- **AND** MUST place `id` under `items.items.properties`

### Requirement: High-frequency Laravel rules are normalized before OpenAPI mapping
The system MUST normalize common Laravel request rules into a stable intermediate format before generating OpenAPI schema.

#### Scenario: Password builder rules are used
- **WHEN** a request field uses `Password::min(...)->letters()->numbers()` style rules
- **THEN** the system MUST split those requirements into individual capabilities
- **AND** MUST preserve reliably mappable constraints in the generated schema

#### Scenario: Partially mappable rules are used
- **WHEN** a request field uses rules such as `exists`, `unique`, or `required_if`
- **THEN** the generated schema MUST preserve any reliably mappable constraints
- **AND** MUST record unresolved portions for later review
