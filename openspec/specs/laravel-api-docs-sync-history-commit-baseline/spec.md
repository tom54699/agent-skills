# laravel-api-docs-sync-history-commit-baseline Specification

## Purpose
TBD - created by archiving change make-candidate-inference-commit-driven. Update Purpose after archive.
## Requirements
### Requirement: Successful sync history MUST persist commit baseline data
The system MUST persist the repository commit boundary needed for the next daily guided-sync run whenever an Apidog sync succeeds.

#### Scenario: Successful sync appends history
- **WHEN** guided-sync completes an Apidog upload successfully
- **THEN** the appended history record MUST include the current `git_head_commit`

#### Scenario: History remains backward compatible
- **WHEN** older history records exist without `git_head_commit`
- **THEN** the system MUST continue accepting those records and MUST NOT require manual history migration before the next run

### Requirement: Daily range selection MUST expose whether commit or time fallback was used
The system MUST make its range-selection basis observable so users can determine whether candidate inference used a commit baseline or a legacy time-window fallback.

#### Scenario: Commit baseline used
- **WHEN** daily guided-sync resolves its diff range from the last successful `git_head_commit`
- **THEN** candidate output metadata MUST identify commit-based range selection

#### Scenario: Time fallback used
- **WHEN** daily guided-sync cannot use the last successful `git_head_commit` and falls back to the legacy time-window strategy
- **THEN** candidate output metadata MUST identify the fallback strategy

