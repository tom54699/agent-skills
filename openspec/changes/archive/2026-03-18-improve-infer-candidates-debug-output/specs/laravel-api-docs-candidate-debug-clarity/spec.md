## ADDED Requirements

### Requirement: Candidate inference debug output SHALL distinguish baseline information from candidate signals
The system MUST present debug output so users can distinguish repository inventory, baseline comparison, and candidate narrowing signals.

#### Scenario: Initialization without OpenAPI baseline
- **WHEN** candidate inference runs in initialization mode without an OpenAPI baseline
- **THEN** debug output explicitly indicates that route/openapi comparison is informational only
- **AND** it MUST NOT imply that all route snapshot entries became candidate endpoints

#### Scenario: User reviews candidate narrowing
- **WHEN** `--debug` is enabled
- **THEN** the output includes separate lines for changed file inventory, class inventory, action hints, prefilter summary, and candidate summary
