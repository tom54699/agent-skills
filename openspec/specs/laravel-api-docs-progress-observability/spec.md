# laravel-api-docs-progress-observability Specification

## Purpose
Define standardized progress and timing output for long-running guided-sync scripts.

## Requirements
### Requirement: Guided-sync scripts SHALL emit standardized progress output
The system MUST emit standardized progress output for guided-sync scripts so the user can see both workflow position and current step progress while execution is ongoing.

#### Scenario: Candidate inference is running
- **WHEN** `infer-candidates.sh` is executing
- **THEN** it emits progress lines that identify the guided-sync step as `infer_candidates`
- **AND** the output includes a workflow checklist showing completed, in-progress, and pending guided-sync steps
- **AND** the current step includes a progress bar and stage label

#### Scenario: OpenAPI generation is running
- **WHEN** `gen-openapi.sh` is executing
- **THEN** it emits progress lines that identify the guided-sync step as `update_openapi`
- **AND** the current step includes progress updates based on processed endpoint count when available

### Requirement: Progress output SHALL preserve JSON stdout contracts
The system MUST preserve each script's existing JSON stdout contract while adding progress observability.

#### Scenario: Script produces JSON result
- **WHEN** a guided-sync script completes successfully
- **THEN** its structured result remains on `stdout`
- **AND** progress and timing information are emitted only to `stderr`

### Requirement: Long-running scripts SHALL emit stage timing telemetry
The system MUST emit stage timing telemetry for long-running guided-sync scripts so bottlenecks can be identified without external profiling.

#### Scenario: infer-candidates completes
- **WHEN** `infer-candidates.sh` finishes
- **THEN** it emits timing lines for at least class index, route snapshot, action hints, candidate evaluation, and output write
- **AND** its result includes a timing summary payload

#### Scenario: gen-openapi completes
- **WHEN** `gen-openapi.sh` finishes
- **THEN** it emits timing lines for at least route snapshot, endpoint generation, merge, deletion handling, and output write
- **AND** its result includes a timing summary payload

### Requirement: Progress emission SHALL be suppressible
The system MUST provide a way to suppress progress output for non-interactive or quiet automation.

#### Scenario: Progress is disabled
- **WHEN** a guided-sync script is invoked with progress suppression enabled
- **THEN** it does not emit checklist or progress bar lines
- **AND** it still emits its normal JSON result or failure message
