## ADDED Requirements

### Requirement: Business Logic Workflow Skill
The repository SHALL provide a `business-logic-workflow` skill that guides scoped business logic understanding, discussion, comparison, and preservation decisions.

#### Scenario: Skill exists in active skills
- **WHEN** a user wants to discuss requirements, understand legacy behavior, compare old and new business logic, or decide whether to preserve business logic documentation
- **THEN** the skill MUST exist under `skills/business-logic-workflow/`
- **AND** the skill MUST include a `SKILL.md` entrypoint

#### Scenario: Workflow is architecture-neutral
- **WHEN** the workflow is used on a project
- **THEN** it MUST NOT require DDD, domain events, aggregates, repositories, or bounded-context code structure
- **AND** it MUST support frontend apps, backend services, scripts, Laravel projects, Flutter projects, and mixed legacy structures

#### Scenario: OpenSpec is optional
- **WHEN** the skill is used
- **THEN** the workflow MUST NOT require an OpenSpec change to exist
- **AND** it MAY produce outputs that later feed OpenSpec, tests, implementation plans, or long-term docs

### Requirement: Demand Brief Mode
The skill SHALL support new requirement analysis before technical planning.

#### Scenario: Requirement ticket is provided
- **WHEN** a user provides a requirement ticket, feature idea, product request, gameplay request, or asks to discuss business logic
- **THEN** the skill MUST identify scope, actors, To-Be workflow, To-Be rules, edge cases, acceptance perspectives, and open questions
- **AND** it MUST NOT start implementation or permanent documentation by default

#### Scenario: Requirement is unclear
- **WHEN** the requirement lacks essential business rules, actors, scope, or edge cases
- **THEN** the skill MUST ask concise clarification questions or mark those points as open questions

#### Scenario: Requirement has blocking uncertainty
- **WHEN** unresolved requirement questions would block safe planning, implementation, testing, or documentation promotion
- **THEN** the skill MUST classify those questions as blocking
- **AND** it MUST ask the user before proceeding

#### Scenario: Requirement has non-blocking uncertainty
- **WHEN** unresolved requirement questions do not block the current task
- **THEN** the skill MUST classify those questions as deferred
- **AND** it MUST record them without interrupting the current task

### Requirement: Legacy As-Is Mode
The skill SHALL support scoped investigation of existing business behavior.

#### Scenario: User asks to understand old behavior
- **WHEN** a user asks what an unfamiliar feature, API, module, workflow, bug, or code path does
- **THEN** the skill MUST define the investigation scope
- **AND** it SHOULD use `.ai-project-index` for routing when available
- **AND** it MUST read original source, tests, docs, specs, configs, or user-provided evidence before stating business behavior

#### Scenario: As-Is claims include evidence
- **WHEN** the skill records current behavior
- **THEN** each confirmed claim MUST cite direct evidence
- **AND** uncertain claims MUST include `needs-confirmation`, low confidence, or an open question

#### Scenario: As-Is uncertainty is classified
- **WHEN** legacy investigation leaves uncertainty
- **THEN** the skill MUST separate blocking questions from deferred questions
- **AND** it MUST ask only blocking questions immediately

### Requirement: Delta Mode
The skill SHALL support comparing old and new business logic for changes or refactors.

#### Scenario: Existing behavior is being changed
- **WHEN** a user wants to refactor, rewrite, migrate, or implement a requirement that affects existing behavior
- **THEN** the skill MUST separate As-Is, To-Be, Delta, unchanged rules, risks, acceptance perspectives, and open questions

#### Scenario: Delta has insufficient As-Is evidence
- **WHEN** old behavior is not supported by enough evidence
- **THEN** the skill MUST mark the missing evidence as a risk or open question
- **AND** it MUST NOT present inferred old behavior as confirmed

#### Scenario: Delta uncertainty is classified
- **WHEN** an unresolved point affects the As-Is, To-Be, Delta, unchanged rules, risks, or acceptance perspectives
- **THEN** the skill MUST classify it as blocking if it affects safe next actions
- **AND** it MUST otherwise record it as deferred

### Requirement: Preservation Mode
The skill SHALL require explicit preservation decisions before writing long-term business docs.

#### Scenario: User wants to preserve business logic
- **WHEN** the user asks to preserve, document, or update long-term business logic docs
- **THEN** the skill MUST decide whether to `not_promoted`, `update_existing`, `create_new`, or leave the decision `pending`
- **AND** it MUST prefer updating existing docs over creating new docs when an appropriate target exists

#### Scenario: No permanent docs by default
- **WHEN** the skill produces a Business Logic Brief, As-Is summary, or Delta
- **THEN** it MUST NOT create `docs/business/` or any permanent documentation tree unless the user explicitly asks for long-term preservation

### Requirement: Output Shapes
The skill SHALL define minimal output shapes for Business Logic Brief, As-Is Summary, Delta, and Preservation Decision.

#### Scenario: Business Logic Brief
- **WHEN** Demand Brief Mode produces output
- **THEN** it SHOULD include status, scope, source, background, scope/non-scope, actors, To-Be workflow, To-Be rules, edge cases, acceptance perspectives, blocking questions, and deferred questions

#### Scenario: As-Is Summary
- **WHEN** Legacy As-Is Mode produces output
- **THEN** it SHOULD include status, scope, confirmed old behavior, evidence, confidence, blocking questions, deferred questions, and change/refactor risks

#### Scenario: Delta Summary
- **WHEN** Delta Mode produces output
- **THEN** it SHOULD include status, scope, As-Is, To-Be, Delta, unchanged rules, risks, acceptance perspectives, blocking questions, and deferred questions
