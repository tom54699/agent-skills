# laravel-openapi-response-example-enrichment Specification

## Purpose
Define how generated OpenAPI responses should preserve richer success and error examples for confirmed endpoints.

## Requirements
### Requirement: Updated endpoints MUST expose richer response information
The system MUST enrich confirmed endpoint responses with more useful success and error information than a fixed default template.

#### Scenario: Updated endpoint has known error signals
- **WHEN** controller, service, or exception parsing yields error messages, error codes, or HTTP status hints for a confirmed endpoint
- **THEN** the generated OpenAPI responses MUST include that information in the corresponding error response description, schema, or example

#### Scenario: Updated endpoint has no specialized response signals
- **WHEN** a confirmed endpoint lacks reliable response detail signals
- **THEN** the generator MUST keep a conservative default response schema
- **AND** it MUST NOT invent detailed payload structures it cannot justify

### Requirement: Updated endpoints MUST include response examples
The system MUST generate response examples for confirmed endpoints, prioritizing error responses and then success responses.

#### Scenario: Error response is available
- **WHEN** a confirmed endpoint has a known error response path such as validation failure, unauthorized access, or domain exception
- **THEN** the generated OpenAPI MUST include an example payload for that response

#### Scenario: Success response is available
- **WHEN** a confirmed endpoint has a success response definition
- **THEN** the generated OpenAPI MUST include at least one basic success example compatible with the response schema

### Requirement: Success response examples prefer controller apiResponse payloads
The system MUST prefer controller `apiResponse()` success payloads over path-name heuristics when generating success response examples.

#### Scenario: apiResponse success data is null
- **WHEN** a controller success response uses `apiResponse(..., null, 200)`
- **THEN** the generated success example MUST NOT invent unrelated payload fields such as login token data

#### Scenario: apiResponse success data is an array literal
- **WHEN** a controller success response uses `apiResponse(..., ['foo' => 'bar'], 200)`
- **THEN** the generated success example MUST reflect those keys inside `data`
