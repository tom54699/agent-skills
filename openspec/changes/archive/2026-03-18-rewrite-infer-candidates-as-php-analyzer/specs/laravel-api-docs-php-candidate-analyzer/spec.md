## ADDED Requirements

### Requirement: Candidate inference SHALL be executed by a single PHP analyzer
The system MUST provide a single PHP-based analyzer for candidate inference instead of relying on shell-heavy multi-script evaluation as the primary execution path.

#### Scenario: Guided sync candidate inference runs
- **WHEN** candidate inference is triggered during guided sync
- **THEN** a single PHP analyzer performs route/change/action/dependency analysis
- **AND** shell scripts act only as orchestration wrappers

### Requirement: The PHP analyzer SHALL preserve current candidate semantics
The system MUST preserve existing `new / updated / deleted` candidate semantics and output shape while changing the implementation strategy.

#### Scenario: Same repository range before and after analyzer rewrite
- **WHEN** the same Laravel repository and Git range are analyzed by the stable shell version and the PHP analyzer
- **THEN** the resulting candidate `status / method / path` set remains equivalent
- **AND** the JSON output remains compatible with guided-sync consumers

### Requirement: The PHP analyzer SHALL emit structured progress and timing events
The system MUST emit machine-readable progress/timing events so the existing guided-sync checklist and progress bar can remain intact.

#### Scenario: Candidate inference runs with progress enabled
- **WHEN** the analyzer is executed through `infer-candidates.sh`
- **THEN** the wrapper can render the same step checklist and progress bar style as before
- **AND** timing output still identifies major stages such as range selection, indexing, subset resolution, evaluation, and output writing
