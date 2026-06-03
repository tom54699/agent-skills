## ADDED Requirements

### Requirement: Understand Anything Evaluation

The project SHALL support an evaluation workflow for running Understand Anything as a current-system understanding layer before deciding whether it can replace repository navigation docs.

#### Scenario: First evaluation run

- **WHEN** Understand Anything is run against this repository
- **THEN** the generated output MUST be inspected for coverage of curated skills, OpenSpec workflow files, accepted specs, docs, and tests before it is treated as useful project context

#### Scenario: Generated artifact policy

- **WHEN** `.understand-anything/` artifacts are generated
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

The project SHALL keep OpenSpec as the required workflow for intended behavior changes while using Understand Anything for current-system discovery.

#### Scenario: Feature development

- **WHEN** a future feature, API, database, workflow, or business-rule change is requested
- **THEN** the agent MUST use current-system discovery before creating or updating an OpenSpec change and MUST NOT implement before the OpenSpec change is clear

#### Scenario: Graph conflict

- **WHEN** generated understanding conflicts with source files, accepted OpenSpec specs, or manually maintained source-of-truth docs
- **THEN** the conflict MUST be reported and the generated understanding MUST NOT override the source of truth
