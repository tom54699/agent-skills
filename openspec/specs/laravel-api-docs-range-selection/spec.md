# laravel-api-docs-range-selection Specification

## Purpose
Define how candidate inference exposes range selection inputs and resolved Git diff ranges.

## Requirements
### Requirement: Initialization range selection MUST expose both user input and resolved diff range
The system MUST distinguish between the user-provided initialization starting commit and the actual diff range used internally for candidate inference.

#### Scenario: Inclusive initialization range is resolved
- **WHEN** initialization runs with `--from-commit <commit>` and that commit has a parent
- **THEN** candidate output metadata MUST retain the original `from_commit`
- **AND** MUST expose the resolved `diff_range` used for analysis

### Requirement: Initialization range selection MUST use inclusive commit semantics
The system MUST resolve initialization ranges so that the selected starting commit contributes its own changes to `changed_files` and candidate inference.

#### Scenario: Changed files include the selected commit
- **WHEN** initialization runs with `--from-commit <commit>` and that commit modifies controller, request, route, or other API-contract files
- **THEN** those files MUST appear in the analyzer's changed-file inventory used to build the candidate subset
