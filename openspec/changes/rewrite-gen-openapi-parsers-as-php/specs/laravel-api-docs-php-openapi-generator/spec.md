## ADDED Requirements

### Requirement: OpenAPI generation SHALL be executed by a single PHP generator
The system MUST provide a single PHP-based generator for `gen-openapi` instead of relying on shell parser scripts as the primary execution path.

#### Scenario: Candidate-driven OpenAPI update runs
- **WHEN** `gen-openapi.sh` is triggered with a confirmed candidate file
- **THEN** a single PHP generator performs controller, request, and service parsing
- **AND** shell scripts act only as orchestration wrappers

### Requirement: The PHP generator SHALL preserve current OpenAPI output contract
The system MUST preserve the current `gen-openapi.sh` command contract and output compatibility while changing the implementation strategy.

#### Scenario: Existing gen-openapi command runs
- **WHEN** the user executes `gen-openapi.sh` with existing supported flags
- **THEN** the command still accepts the same arguments
- **AND** the resulting `openapi.yaml` remains compatible with downstream upload and HTML steps

### Requirement: The PHP generator SHALL replace shell parser scripts on the main path
The system MUST stop using `parse-controller.sh`, `parse-service.sh`, and `parse-form-request.sh` as the main parser path for OpenAPI generation.

#### Scenario: OpenAPI operation is built
- **WHEN** the generator needs controller, service, or FormRequest metadata
- **THEN** it resolves that metadata inside the PHP process
- **AND** it does not spawn shell parser scripts for the primary generation flow
