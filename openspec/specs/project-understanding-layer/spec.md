# project-understanding-layer Specification

## Purpose
定義本專案如何評估並使用 current-system understanding layer，包括 upstream Understand Anything 與本專案的輕量 AI project index，同時維持 OpenSpec 作為 intended behavior change 的 source of truth。

## Requirements
### Requirement: Understand Anything Evaluation
The project SHALL support evaluation workflows for current-system understanding layers, including upstream Understand Anything and the repository's lightweight AI project index, before deciding whether generated artifacts can replace repository navigation docs.

#### Scenario: First evaluation run
- **WHEN** a current-system understanding layer is run against this repository
- **THEN** the generated output MUST be inspected for coverage of curated skills, OpenSpec workflow files, accepted specs, docs, and tests before it is treated as useful project context

#### Scenario: Generated artifact policy
- **WHEN** generated understanding artifacts are produced
- **THEN** the project MUST decide whether each artifact is committed, ignored, or regenerated locally before adding it to version control

### Requirement: Documentation Replacement Classification
The project SHALL classify documentation by whether Understand Anything can replace it, partially replace it, or only index it.

#### Scenario: Replaceable navigation documentation
- **WHEN** documentation only describes project structure, module location, reading order, or file purpose
- **THEN** the documentation MAY be replaced by Understand Anything output after the generated output is verified

#### Scenario: Manual source of truth documentation
- **WHEN** documentation records human business decisions, external policies, ADRs, or accepted OpenSpec behavior
- **THEN** the documentation MUST remain a source of truth and Understand Anything MAY only index or summarize it

### Requirement: OpenSpec Coordination
The project SHALL keep OpenSpec as the required workflow for intended behavior changes while using generated project indexes for current-system discovery.

#### Scenario: Feature development
- **WHEN** a future feature, API, database, workflow, or business-rule change is requested
- **THEN** the agent MUST use current-system discovery before creating or updating an OpenSpec change
- **AND** the agent MUST verify important generated-index claims against source files, accepted OpenSpec specs, manually maintained source-of-truth docs, or tests before implementation
- **AND** the agent MUST NOT implement before the OpenSpec change is clear

#### Scenario: Graph conflict
- **WHEN** generated understanding conflicts with source files, accepted OpenSpec specs, or manually maintained source-of-truth docs
- **THEN** the conflict MUST be reported
- **AND** the generated understanding MUST NOT override the source of truth

#### Scenario: AI index query
- **WHEN** an agent uses a generated AI project index for discovery
- **THEN** the agent MUST query the index for candidate paths rather than loading the full index into model context
- **AND** the agent MUST read original source-of-truth files before making behavior claims
