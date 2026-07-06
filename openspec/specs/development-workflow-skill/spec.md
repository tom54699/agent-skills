# development-workflow-skill Specification

## Purpose
定義 `development-workflow` skill 作為 AI-assisted development 的薄層協調入口，負責新專案初始化、專案協作規則模板，以及日常工作如何分流到 specialized workflow skills。
## Requirements
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

#### Scenario: Project signals include technology stack detection
- **WHEN** the skill inspects project signals during init
- **THEN** it MUST also detect PHP/Laravel, Python, frontend framework, and Prisma signals from project files (`composer.json`, `requirements.txt`/`pyproject.toml`, `package.json`, `schema.prisma`)
- **AND** the initialization plan MUST list detected stack signals and corresponding plugin recommendations before asking for confirmation

#### Scenario: Re-running init reads prior plugin decisions
- **WHEN** `init` runs on a project that already has a "Plugin Decisions" record in `AGENTS.md` or `CLAUDE.md`
- **THEN** the skill MUST read that record before producing new plugin recommendations
- **AND** it MUST also check the project's `.claude/settings.json` `enabledPlugins` (when present) as the authoritative signal for what is actually installed

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

### Requirement: Plugin Recommendations
The skill SHALL classify Claude Code marketplace plugins into recommendation tiers during init, based on project signals and prior evaluation of the `claude-plugins-official` marketplace.

#### Scenario: Mandatory tier is always suggested
- **WHEN** the skill produces plugin recommendations during init
- **THEN** it MUST include `context7`, `skill-creator`, and `hookify` in a mandatory tier regardless of detected project signals

#### Scenario: Stack-specific tier depends on detected signals
- **WHEN** a PHP/Laravel, Python, frontend framework, or Prisma signal is detected
- **THEN** the skill MUST use the AskUserQuestion tool to present the corresponding stack-specific plugins (`laravel-boost`/`php-lsp` for PHP/Laravel, `pyright-lsp` for Python, `figma`/`frontend-design`/`typescript-lsp`/`playwright`/`chrome-devtools-mcp` for frontend, `prisma` only when `schema.prisma` is detected) as an interactive multi-select choice, rather than only listing them in the written initialization plan
- **AND** it MUST NOT suggest a stack-specific plugin when its corresponding signal is absent

#### Scenario: Conditional tier requires explicit caveat disclosure
- **WHEN** the skill recommends `security-guidance` or `claude-md-management`
- **THEN** it MUST disclose known limitations before recommending: for `security-guidance`, that per-turn and per-commit reviews consume model usage with no published token benchmark, and that a trial period with usage measurement is recommended before committing long-term; for `claude-md-management`, that its suggestions follow generic CLAUDE.md conventions rather than this project's `development-workflow` template and OpenSpec conventions, and that its output must be reviewed before being applied

#### Scenario: Excluded plugins are not suggested but explained on request
- **WHEN** the user asks why a specific plugin was not recommended
- **THEN** the skill MUST be able to state the specific exclusion reason for `code-review`, `code-simplifier`, `feature-dev`, `ralph-loop`, `mgrep`, and `claude-context` (overlap with existing skills, conflict with the OpenSpec change-record requirement, or code content leaving the local machine)

#### Scenario: Already-installed plugins are not suggested again
- **WHEN** a candidate plugin (mandatory, stack-specific, or conditional tier) is already installed according to `enabledPlugins` or the recorded Plugin Decisions
- **THEN** the skill MUST NOT re-suggest installing it
- **AND** the initialization plan MUST list it under an "already installed" status instead

#### Scenario: Excluded plugin already installed produces a conflict note
- **WHEN** a plugin from the excluded tier is detected as already installed in the target project
- **THEN** the skill MUST surface a one-line conflict note explaining the known reason for exclusion
- **AND** it MUST NOT suggest uninstalling or disabling the plugin

#### Scenario: Plugin decisions are recorded for future init runs
- **WHEN** the user confirms an initialization plan that includes plugin recommendations
- **THEN** the skill MUST record each plugin's resulting status (installed, declined, or excluded-conflict-noted) in a "Plugin Decisions" section of `AGENTS.md` or `CLAUDE.md`

#### Scenario: Install scope has tier-based defaults
- **WHEN** the skill recommends installing a plugin
- **THEN** it MUST propose a default install scope (Claude Code user/global scope for the mandatory tier, project-shared scope for the stack-specific and conditional tiers)
- **AND** the recorded Plugin Decisions MUST capture the resulting scope

#### Scenario: Install scope is confirmed by the user
- **WHEN** the skill proposes a default install scope for one or more plugins
- **THEN** it MUST let the user confirm or override the scope before treating a plugin as decided
- **AND** it MUST NOT assume the default scope without confirmation

### Requirement: Hook Recommendations
The skill SHALL suggest using the `hookify` plugin to enforce two specific rules as hooks instead of relying on prose reminders alone.

#### Scenario: Index refresh rule is suggested
- **WHEN** `hookify` is installed or being recommended as part of the mandatory tier
- **THEN** the skill MUST suggest a rule that reminds or triggers `.ai-project-index` refresh after edits to `skills/**/SKILL.md`, `AGENTS.md`, or `CLAUDE.md`

#### Scenario: Pre-commit OpenSpec validation rule is suggested
- **WHEN** `hookify` is installed or being recommended as part of the mandatory tier
- **THEN** the skill MUST suggest a rule that reminds the user to run `openspec validate --strict` before `git commit` when an active (non-archived) OpenSpec change exists

#### Scenario: Hook creation remains optional
- **WHEN** the skill suggests hook rules
- **THEN** it MUST NOT create any hook configuration file itself
- **AND** it MUST leave the decision to actually install `hookify` and create the rules to the user

### Requirement: Skill Version Metadata
The skill SHALL carry a version identifier to support future compatibility checks.

#### Scenario: SKILL.md declares a version
- **WHEN** the skill's frontmatter is inspected
- **THEN** it MUST include a `metadata.version` field
- **AND** this field is informational only in this change — no automated comparison logic is required yet

