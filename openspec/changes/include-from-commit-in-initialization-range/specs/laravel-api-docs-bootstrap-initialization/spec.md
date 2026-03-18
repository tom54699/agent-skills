## MODIFIED Requirements

### Requirement: Initialization SHALL require a starting commit when no success history exists
When no successful sync history is available, the skill MUST run initialization mode and require the user to provide a starting commit for API candidate inference.

#### Scenario: Initialization starts from a user-provided commit
- **WHEN** `docs/api-docs/history/apidog-sync-history.jsonl` has no `status=success` record
- **AND** the user provides `--from-commit <commit>`
- **THEN** the analyzer MUST use initialization mode for candidate inference

### Requirement: Initialization from-commit MUST include the specified commit itself
The system MUST treat initialization `--from-commit` as an inclusive starting point rather than directly reusing Git's exclusionary `<commit>..HEAD` semantics.

#### Scenario: User selects a feature-start commit
- **WHEN** initialization runs with `--from-commit <commit>` and that commit has a parent
- **THEN** the resolved initialization diff MUST include changes introduced by `<commit>` itself
- **AND** candidate inference MUST consider files changed in `<commit>` together with later commits up to `HEAD`

#### Scenario: Root commit is provided
- **WHEN** initialization runs with `--from-commit <commit>` and that commit has no parent
- **THEN** the system MUST fail with a clear error telling the user to provide a commit that has a parent
