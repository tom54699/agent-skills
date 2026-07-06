## MODIFIED Requirements

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
