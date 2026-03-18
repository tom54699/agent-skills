## MODIFIED Requirements

### Requirement: Candidate inference MUST prioritize API contract and documentation surface changes
The system MUST emit daily or initialization `updated` candidates only when the selected diff range changes API contract surface or documentation surface that can affect generated OpenAPI output.

#### Scenario: Request contract change emits updated candidate
- **WHEN** the resolved diff range changes a FormRequest or inline validation rule used by `Controller@action`
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

#### Scenario: Response contract change emits updated candidate
- **WHEN** the resolved diff range changes a Resource, structured return response, response annotation, or response documentation used by `Controller@action`
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

#### Scenario: Error contract change emits updated candidate
- **WHEN** the resolved diff range changes exception mapping, status code, error description, or error payload shape exposed by an endpoint
- **THEN** the endpoint affected by that error contract change MUST be emitted as `status=updated`

### Requirement: Weak implementation signals MUST NOT independently create updated candidates
The system MUST treat raw controller method body diffs and raw service method body diffs as weak signals, and MUST NOT emit an `updated` candidate from those weak signals alone.

#### Scenario: Controller body-only refactor is ignored
- **WHEN** the resolved diff range changes only the controller method body
- **AND** no route, request, response, error contract, or documentation annotation signal is detected
- **THEN** candidate inference MUST NOT emit the related endpoint as `status=updated`

#### Scenario: Service body-only refactor is ignored
- **WHEN** the resolved diff range changes only a service method body such as enum replacement, helper argument refactor, cache key composition, or local variable flow
- **AND** no request, response, error contract, or documentation annotation signal is detected
- **THEN** candidate inference MUST NOT emit the related endpoint as `status=updated`

### Requirement: Documentation annotations MUST be treated as first-class candidate signals
The system MUST treat function-level documentation annotations that map to OpenAPI content as strong `updated` signals when they change within the selected diff range.

#### Scenario: Description change emits updated candidate
- **WHEN** the resolved diff range changes a function phpdoc description or summary used as OpenAPI description text
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

#### Scenario: OpenAPI-mapped annotation parameter change emits updated candidate
- **WHEN** the resolved diff range changes `@queryParam`, `@bodyParam`, `@urlParam`, `@response`, `@responseFile`, `@responseField`, or another supported annotation that maps to generated OpenAPI content
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

### Requirement: Candidate output MUST distinguish strong and weak signals
Each emitted candidate MUST include reasons or signals that identify whether the trigger came from strong contract/doc signals or from weak implementation signals that were only corroborative.

#### Scenario: Updated candidate identifies signal category
- **WHEN** an endpoint is emitted as `status=updated`
- **THEN** its output MUST indicate whether the trigger came from route, request, response, error contract, or documentation annotation signals
- **AND** weak implementation signals MUST NOT be represented as the sole cause of the candidate
