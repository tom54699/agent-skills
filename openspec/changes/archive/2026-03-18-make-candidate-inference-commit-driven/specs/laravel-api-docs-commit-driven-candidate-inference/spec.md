## ADDED Requirements

### Requirement: Daily candidate inference MUST use commit-scoped change ranges
The system MUST derive daily guided-sync candidate ranges from the last successful sync commit when that commit is available, rather than treating `synced_at` as the primary boundary.

#### Scenario: Last successful sync commit is available
- **WHEN** guided-sync runs in daily mode and the latest success history record contains a valid `git_head_commit` that exists in the current repository
- **THEN** the analyzer MUST use `<git_head_commit>..HEAD` as the diff range for candidate inference

#### Scenario: Commit baseline is unavailable
- **WHEN** guided-sync runs in daily mode and the latest success history record does not provide a usable `git_head_commit`
- **THEN** the analyzer MUST fall back to the existing time-window strategy

### Requirement: Daily new and updated candidates MUST come from current change signals
The system MUST build daily `new` and `updated` candidates from route, controller, request, resource, service, and exception signals inside the resolved diff range, and MUST NOT emit those candidates solely because an endpoint is absent from the local OpenAPI baseline.

#### Scenario: Thin baseline without API changes
- **WHEN** guided-sync runs in daily mode, the local OpenAPI baseline contains far fewer endpoints than the current Laravel route list, and the resolved diff range does not include API-related changes
- **THEN** the analyzer MUST NOT emit a bulk `new` candidate list derived only from route-versus-baseline set difference

#### Scenario: Route addition inside current diff range
- **WHEN** the resolved diff range contains route changes that introduce a new action or endpoint mapping
- **THEN** the analyzer MUST emit the impacted endpoint as a `new` candidate

#### Scenario: Dependency-driven endpoint change inside current diff range
- **WHEN** the resolved diff range changes a controller, request, resource, service, or exception that maps to an existing endpoint
- **THEN** the analyzer MUST emit that endpoint as an `updated` candidate even if the local OpenAPI baseline does not currently contain the operation

### Requirement: Baseline coverage MUST be diagnostic-only for daily new candidate narrowing
The system MUST treat local OpenAPI coverage gaps as diagnostic information for daily candidate inference, not as an automatic source of `new` candidates.

#### Scenario: Daily run with baseline gaps
- **WHEN** guided-sync runs in daily mode with an existing local OpenAPI baseline that is missing many current routes
- **THEN** the analyzer MUST report the baseline gap through debug or meta diagnostics without automatically converting those gaps into `new` candidates

#### Scenario: Deleted endpoints still require baseline
- **WHEN** guided-sync runs in daily mode with a valid local OpenAPI baseline
- **THEN** the analyzer MAY continue using baseline-versus-route comparison to produce `deleted` candidates
