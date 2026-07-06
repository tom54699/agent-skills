## MODIFIED Requirements

### Requirement: Output Shapes
The skill SHALL define minimal output shapes for Business Logic Brief, As-Is Summary, Delta, and Preservation Decision.

#### Scenario: Business Logic Brief
- **WHEN** Demand Brief Mode produces output
- **THEN** it SHOULD include status, a generated-by skill version marker, scope, source, background, scope/non-scope, actors, To-Be workflow, To-Be rules, edge cases, acceptance perspectives, blocking questions, and deferred questions

#### Scenario: As-Is Summary
- **WHEN** Legacy As-Is Mode produces output
- **THEN** it SHOULD include status, a generated-by skill version marker, scope, confirmed old behavior, evidence, confidence, blocking questions, deferred questions, and change/refactor risks

#### Scenario: Delta Summary
- **WHEN** Delta Mode produces output
- **THEN** it SHOULD include status, a generated-by skill version marker, scope, As-Is, To-Be, Delta, unchanged rules, risks, acceptance perspectives, blocking questions, and deferred questions

## ADDED Requirements

### Requirement: Skill Version Metadata
The skill SHALL carry a version identifier to support future compatibility checks.

#### Scenario: SKILL.md declares a version
- **WHEN** the skill's frontmatter is inspected
- **THEN** it MUST include a `metadata.version` field
