## MODIFIED Requirements

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

### Requirement: Plugin Recommendations
The skill SHALL classify Claude Code marketplace plugins into recommendation tiers during init, based on project signals and prior evaluation of the `claude-plugins-official` marketplace.

#### Scenario: Mandatory tier is always suggested
- **WHEN** the skill produces plugin recommendations during init
- **THEN** it MUST include `context7`, `skill-creator`, and `hookify` in a mandatory tier regardless of detected project signals

#### Scenario: Stack-specific tier depends on detected signals
- **WHEN** a PHP/Laravel, Python, frontend framework, or Prisma signal is detected
- **THEN** the skill MUST offer the corresponding stack-specific plugins (`laravel-boost`/`php-lsp` for PHP/Laravel, `pyright-lsp` for Python, `figma`/`frontend-design`/`typescript-lsp`/`playwright`/`chrome-devtools-mcp` for frontend, `prisma` only when `schema.prisma` is detected) as a multi-select choice
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

## ADDED Requirements

### Requirement: Skill Version Metadata
The skill SHALL carry a version identifier to support future compatibility checks.

#### Scenario: SKILL.md declares a version
- **WHEN** the skill's frontmatter is inspected
- **THEN** it MUST include a `metadata.version` field
- **AND** this field is informational only in this change — no automated comparison logic is required yet
