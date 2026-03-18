# laravel-api-docs-initialization-updated-inference Specification

## Purpose
TBD - created by archiving change include-updated-in-initialization-without-llm. Update Purpose after archive.
## Requirements
### Requirement: Initialization inference SHALL include updated endpoints without LLM
When no successful sync history exists, candidate inference MUST include both `new` and `updated` endpoint candidates within the user-provided commit range.

#### Scenario: Initialization range inference includes updated
- **WHEN** history has no `status=success` and user provides `from_commit`
- **THEN** inference output includes candidates with `status=new` and `status=updated`

#### Scenario: Initialization inference excludes deleted by default
- **WHEN** initialization inference runs without baseline
- **THEN** inference output MUST NOT auto-produce `status=deleted` candidates

### Requirement: System SHALL infer updated endpoints from reverse dependency changes
The system MUST map non-controller file changes back to affected endpoints using deterministic reverse dependency rules.

#### Scenario: FormRequest change maps to updated endpoint
- **WHEN** a changed file under `app/Http/Requests/` is associated with `Controller@action`
- **THEN** the corresponding endpoint is emitted as `status=updated`

#### Scenario: Service change maps to updated endpoint
- **WHEN** a changed file under `app/Services/` is referenced by a controller action bound to a route
- **THEN** the corresponding endpoint is emitted as `status=updated`

#### Scenario: Exception change maps to updated endpoint
- **WHEN** a changed file under `app/Exceptions/` is referenced by service/controller error flow
- **THEN** the corresponding endpoint is emitted as `status=updated`

### Requirement: Response inference SHALL support project-specific apiResponse and BaseException pattern
The system MUST parse response signals from project conventions to improve OpenAPI response accuracy without LLM.

#### Scenario: Success response inferred from apiResponse helper
- **WHEN** controller action returns `response()->apiResponse(code, message, data, status)`
- **THEN** candidate analysis captures success response code/status and payload structure hints

#### Scenario: Error response inferred from BaseException getters
- **WHEN** controller catches an exception derived from `BaseException`
- **THEN** candidate analysis captures `error_code`, `message`, `data`, and HTTP status via getter methods

#### Scenario: Throwable fallback inferred as 500
- **WHEN** controller catches `Throwable` and returns apiResponse fallback
- **THEN** candidate analysis includes a fallback error response with HTTP 500

### Requirement: Candidate output SHALL include review signals for safe human confirmation
Candidate output MUST include explainable metadata to support user confirmation before OpenAPI update.

#### Scenario: Candidate includes reason and confidence
- **WHEN** a candidate endpoint is emitted
- **THEN** output includes `change_reason` and `confidence` fields

#### Scenario: Candidate includes missing fields signal
- **WHEN** parser cannot confidently determine request or response schema
- **THEN** output includes `missing_fields` entries for manual completion

