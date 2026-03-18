## NEW Requirements

### Requirement: Response generation analyzes actual controller return forms
The system MUST analyze actual controller return response forms before generating OpenAPI response schema and examples.

#### Scenario: Controller returns a JSON helper response
- **WHEN** a controller returns `response()->json(['foo' => 'bar'], 200)`
- **THEN** the generated `200` response MUST reflect those payload keys instead of a generic `data` placeholder

#### Scenario: Controller returns an array literal
- **WHEN** a controller returns an array literal directly
- **THEN** the generated response example MUST reflect that literal payload when it can be safely resolved

### Requirement: Project-specific response wrappers use adapters
The system MUST use a project-specific adapter for response wrappers that are not standard Laravel primitives.

#### Scenario: Project uses apiResponse wrapper
- **WHEN** a controller returns `response()->apiResponse(code, message, data, status)`
- **THEN** the generated response schema MUST reflect the adapter-defined envelope fields
- **AND** MUST NOT hardcode that wrapper as a universal Laravel response format
