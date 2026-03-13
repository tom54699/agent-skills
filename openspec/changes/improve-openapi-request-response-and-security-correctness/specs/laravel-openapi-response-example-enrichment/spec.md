## MODIFIED Requirements

### Requirement: Success response examples prefer controller apiResponse payloads
The system MUST prefer controller `apiResponse()` success payloads over path-name heuristics when generating success response examples.

#### Scenario: apiResponse success data is null
- **WHEN** a controller success response uses `apiResponse(..., null, 200)`
- **THEN** the generated success example MUST NOT invent unrelated payload fields such as login token data

#### Scenario: apiResponse success data is an array literal
- **WHEN** a controller success response uses `apiResponse(..., ['foo' => 'bar'], 200)`
- **THEN** the generated success example MUST reflect those keys inside `data`
