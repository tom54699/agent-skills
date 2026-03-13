## ADDED Requirements

### Requirement: Updated endpoints MUST expose richer response information
The system MUST enrich updated endpoint responses with more useful success/error information than the current fixed default template.

#### Scenario: Updated endpoint has known error signals
- **WHEN** controller, service, or exception parsing yields error messages, error codes, or HTTP status hints for an updated endpoint
- **THEN** the generated OpenAPI responses MUST include that information in the corresponding error response description, schema, or example

#### Scenario: Updated endpoint has no specialized response signals
- **WHEN** an updated endpoint lacks reliable response detail signals
- **THEN** the generator MUST keep a conservative default response schema
- **AND** it MUST not invent detailed payload structures it cannot justify

### Requirement: Updated endpoints MUST include response examples
The system MUST generate response examples for updated endpoints, prioritizing error responses and then success responses.

#### Scenario: Error response is available
- **WHEN** an updated endpoint has a known error response path such as validation failure, unauthorized access, or domain exception
- **THEN** the generated OpenAPI MUST include an example payload for that response

#### Scenario: Success response is available
- **WHEN** an updated endpoint has a success response definition
- **THEN** the generated OpenAPI MUST include at least one basic success example compatible with the response schema
