## ADDED Requirements

### Requirement: Development Workflow Skill
The repository SHALL provide a `development-workflow` skill that coordinates AI project initialization and day-to-day development workflow routing.

#### Scenario: Skill exists in active skills
- **WHEN** a user wants to initialize project AI collaboration rules or define how workflow skills work together
- **THEN** the skill MUST exist under `skills/development-workflow/`
- **AND** the skill MUST include a `SKILL.md` entrypoint

#### Scenario: Skill does not replace specialized workflows
- **WHEN** the development workflow needs business logic analysis, project indexing, or OpenSpec change execution
- **THEN** it MUST route to the corresponding specialized workflow
- **AND** it MUST NOT duplicate the full instructions of those specialized workflows

### Requirement: Init Command
The skill SHALL define a `development-workflow init` entrypoint for bootstrapping AI collaboration rules in a project.

#### Scenario: User runs init
- **WHEN** the user asks for `development-workflow init`
- **THEN** the skill MUST inspect existing project signals before changing files
- **AND** it MUST produce an initialization plan that lists files to create or update, recommended skills, and project-specific assumptions
- **AND** it MUST ask for confirmation before writing project policy files

#### Scenario: Policy files are generated
- **WHEN** the user confirms the initialization plan
- **THEN** the skill MUST create or update `AGENTS.md` and `CLAUDE.md`
- **AND** those files MUST describe the project collaboration rules, skill routing, documentation rules, and update responsibilities

#### Scenario: Existing policy files are present
- **WHEN** `AGENTS.md` or `CLAUDE.md` already exists
- **THEN** the skill MUST preserve project-specific rules
- **AND** it MUST merge or propose changes instead of blindly replacing the file

### Requirement: Skill Routing Workflow
The skill SHALL define how `business-logic-workflow`, OpenSpec workflow skills, and `ai-project-index` are used together.

#### Scenario: New requirement is received
- **WHEN** the user provides a requirement ticket, feature idea, product request, or gameplay request
- **THEN** the workflow MUST route first to `business-logic-workflow` for a scoped business logic brief when behavior or rules are involved
- **AND** it MUST route to OpenSpec proposal after the business scope is clear and implementation is intended

#### Scenario: Legacy behavior or refactor is requested
- **WHEN** the user asks to understand, refactor, rewrite, migrate, or safely change unfamiliar existing behavior
- **THEN** the workflow MUST route to `business-logic-workflow` Legacy As-Is or Delta mode before implementation planning
- **AND** it MUST require evidence from source, tests, docs, specs, or user-provided material before treating old behavior as confirmed

#### Scenario: Project understanding is needed
- **WHEN** the agent needs to find relevant modules, docs, specs, tests, or entrypoints
- **THEN** the workflow SHOULD use `.ai-project-index` as a routing aid when available
- **AND** it MUST treat original source, tests, docs, and specs as source of truth

#### Scenario: OpenSpec change is required
- **WHEN** the task changes features, APIs, configuration, workflows, project policy, documentation contracts, or persistent behavior
- **THEN** the workflow MUST route through OpenSpec proposal, apply, and archive phases according to the project rules

### Requirement: Lightweight Technical Fix Path
The skill SHALL define when a technical fix can avoid the full business logic path.

#### Scenario: Pure technical small fix
- **WHEN** a task does not alter user-visible behavior, business rules, data meaning, API contracts, permissions, payments, notifications, or state transitions
- **THEN** the workflow MAY skip a full business logic brief
- **AND** it MUST still follow the project policy for OpenSpec, tests, and docs

#### Scenario: Small fix affects behavior
- **WHEN** a small-looking fix changes behavior, contracts, data meaning, permissions, or workflows
- **THEN** the workflow MUST NOT use the lightweight path
- **AND** it MUST route through business logic clarification or OpenSpec as appropriate

### Requirement: Collaboration Rule Templates
The skill SHALL provide reusable templates for project-level AI collaboration files.

#### Scenario: Templates are available
- **WHEN** the skill is installed
- **THEN** it MUST include reusable templates for `AGENTS.md` and `CLAUDE.md`
- **AND** the templates MUST prioritize Traditional Chinese, backend-oriented discussion, requirement confirmation before implementation, documentation update responsibilities, and skill routing rules

#### Scenario: Templates are adapted
- **WHEN** templates are used during init
- **THEN** the workflow MUST adapt placeholders and project-specific sections to the target repository
- **AND** it MUST NOT leave unresolved placeholder text in generated policy files
