# laravel-api-docs-candidate-evaluation-performance Specification

## Purpose
TBD - created by archiving change optimize-infer-candidates-evaluation-performance. Update Purpose after archive.
## Requirements
### Requirement: Candidate evaluation SHALL operate on a narrowed impacted route subset
The system MUST narrow the route work set before deep candidate evaluation begins.

#### Scenario: Initialization without OpenAPI baseline
- **WHEN** candidate inference runs in initialization mode without an OpenAPI baseline
- **THEN** the system first builds a `candidate_route_subset` from route/controller/dependency hints
- **AND** deep evaluation iterates only that subset instead of the full route snapshot

#### Scenario: Daily mode with baseline
- **WHEN** candidate inference runs with an OpenAPI baseline
- **THEN** the system limits deep evaluation to routes that are baseline-new or hit current change signals

### Requirement: Candidate evaluation SHALL preserve existing candidate semantics after subset narrowing
The system MUST keep existing `new / updated / deleted` semantics while moving prefilter logic earlier.

#### Scenario: Same repository range before and after optimization
- **WHEN** the same Git range is evaluated before and after the optimization
- **THEN** the candidate statuses and endpoint keys remain equivalent
- **AND** only the route work set size and execution cost change

