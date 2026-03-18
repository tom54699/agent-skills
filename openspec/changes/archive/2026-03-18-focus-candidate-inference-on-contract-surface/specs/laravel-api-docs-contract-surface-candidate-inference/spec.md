## ADDED Requirements

### Requirement: Candidate inference MUST prioritize API contract and documentation surface changes
The system MUST emit daily `updated` candidates only when the selected diff range changes API contract surface or documentation surface that can affect generated OpenAPI output.

#### Scenario: Request contract change emits updated candidate
- **WHEN** the resolved diff range changes a FormRequest or inline validation rule used by `Controller@action`
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

#### Scenario: Response contract change emits updated candidate
- **WHEN** the resolved diff range changes a Resource, structured return response, or response annotation used by `Controller@action`
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

#### Scenario: Error contract change emits updated candidate
- **WHEN** the resolved diff range changes exception mapping, status code, error description, or error payload shape exposed by an endpoint
- **THEN** the endpoint affected by that error contract change MUST be emitted as `status=updated`

### Requirement: Internal-only implementation changes MUST NOT independently create updated candidates
The system MUST NOT emit an `updated` candidate solely because internal implementation changed if that change does not alter request schema, response schema, error contract, route mapping, or documentation surface.

#### Scenario: Service internal variable change is ignored
- **WHEN** the resolved diff range changes only local variables or internal control flow inside a service method
- **AND** no request, response, error contract, route, or documentation surface change is detected
- **THEN** candidate inference MUST NOT emit the related endpoint as `status=updated` solely from that service change

#### Scenario: Repository or query detail change is ignored
- **WHEN** the resolved diff range changes repository usage, SQL conditions, or query ordering without changing API-visible contract
- **THEN** candidate inference MUST NOT emit the related endpoint as `status=updated` solely from that internal change

### Requirement: Documentation annotations MUST be treated as candidate signals
The system MUST treat controller documentation annotations that map to OpenAPI content as `updated` signals when they change within the selected diff range.

#### Scenario: Description change emits updated candidate
- **WHEN** the resolved diff range changes a controller action phpdoc description that is used as OpenAPI description text
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

#### Scenario: Annotation parameter change emits updated candidate
- **WHEN** the resolved diff range changes an annotation parameter that maps to OpenAPI parameters, request metadata, or response metadata
- **THEN** the endpoint bound to that action MUST be emitted as `status=updated`

### Requirement: Route additions and deletions MUST preserve existing candidate status semantics
The system MUST keep `new` and `deleted` semantics aligned with route-level contract changes while applying the narrower `updated` rules.

#### Scenario: New route remains new
- **WHEN** the resolved diff range introduces a new route or endpoint mapping
- **THEN** candidate inference MUST emit that endpoint as `status=new`

#### Scenario: Removed route remains deleted
- **WHEN** daily mode has an OpenAPI baseline and the current route snapshot no longer contains an endpoint present in that baseline
- **THEN** candidate inference MUST emit that endpoint as `status=deleted`

### Requirement: Candidate output MUST explain contract-surface reasoning
Each emitted candidate MUST include reasons or signals that identify which contract or documentation surface changed.

#### Scenario: Updated candidate identifies contract signal
- **WHEN** an endpoint is emitted as `status=updated`
- **THEN** its output MUST indicate whether the trigger came from request, response, error contract, route mapping, or documentation annotation signals

#### Scenario: Internal-only changes do not masquerade as contract updates
- **WHEN** an endpoint is not emitted because only internal implementation changed
- **THEN** diagnostics or debug output MUST NOT describe that endpoint as a contract-surface candidate
