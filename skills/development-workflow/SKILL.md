---
name: development-workflow
description: Use when the user asks to initialize a project workflow, run `development-workflow init`, define AI collaboration rules, create AGENTS.md/CLAUDE.md, decide which workflow skill to use, or coordinate business logic, OpenSpec, project index, docs, tests, and implementation steps.
metadata:
  version: "1.0.0"
---

# Development Workflow

Use this skill as the thin coordination layer for AI-assisted development. It defines how to initialize a project and how to route daily work to the right specialized workflow.

This skill does not replace `business-logic-workflow`, OpenSpec workflow skills, or `ai-project-index`. It decides when to use them and what project-level rules should exist.

## Core Rules

- Use Traditional Chinese when working in this repository or when the target project asks for it.
- Keep the workflow pragmatic. Do not introduce process steps that do not change the outcome.
- Treat project policy files as important project changes. Inspect existing files and propose a plan before writing.
- Do not overwrite `AGENTS.md`, `CLAUDE.md`, OpenSpec files, or docs blindly.
- If a target project has stricter rules than this skill, follow the target project rules.
- Prefer specialized skills for their domains:
  - `business-logic-workflow` for requirements, old behavior, business rules, As-Is/To-Be/Delta, and preservation decisions.
  - OpenSpec workflow skills for proposal, implementation tasks, validation, and archive when the project requires change records.
  - `ai-project-index` for compact routing to relevant source/spec/test/doc files.

## Entry Points

### `development-workflow init`

Use when the user wants to initialize AI collaboration rules in a new or existing project.

Workflow:

1. Inspect project signals:
   - existing `AGENTS.md`, `CLAUDE.md`, `README.md`, docs, OpenSpec config, package files, framework files, tests, and skill folders
   - project type, likely stack, docs convention, and whether OpenSpec is already present
   - technology stack signals for plugin recommendations: `composer.json` containing `laravel/framework` (PHP/Laravel), `requirements.txt`/`pyproject.toml` (Python), `package.json` containing a frontend framework (frontend), `schema.prisma` (Prisma)
   - whether `hookify` is already installed (affects how Hook Recommendations are phrased)
   - the target project's `.claude/settings.json` `enabledPlugins` (if present) — the authoritative signal for what is actually installed
   - any existing "Plugin Decisions" record in `AGENTS.md`/`CLAUDE.md` from a prior `init` run
2. Produce an initialization plan before editing:
   - files to create or update
   - skills to install or verify
   - plugin recommendations (see "Plugin Recommendations")
   - project-specific assumptions
   - rules that need user confirmation
3. Ask for confirmation before writing policy files.
4. After confirmation, create or update `AGENTS.md` and `CLAUDE.md`.
5. If relevant, create minimal `docs/` or OpenSpec setup only when the user confirmed those project policies.
6. Report what changed and what should be done after future commits.

Use these templates as starting points:

- `assets/AGENTS.template.md`
- `assets/CLAUDE.template.md`

Adapt templates to the target repository. Remove template-only notes and unresolved placeholders before writing final files.

### New Requirement

Use when the user provides a requirement ticket, feature idea, product request, gameplay request, or asks to build new behavior.

Default route:

1. Use `business-logic-workflow` Demand Brief Mode if behavior, rules, actors, workflows, state transitions, rewards, permissions, pricing, notifications, or data meaning are involved.
2. Resolve blocking business questions before technical planning.
3. If implementation is intended and the project requires change records, create an OpenSpec change.
4. Implement through the project’s apply workflow.
5. Update tests and docs according to project rules.
6. Refresh `.ai-project-index` after meaningful source/spec/doc/test changes when that skill is installed.

### Legacy Change Or Refactor

Use when the user asks to understand old code, modify unfamiliar behavior, refactor safely, rewrite a module, or compare current behavior with a new requirement.

Default route:

1. Use `.ai-project-index` only as a routing aid when available.
2. Use `business-logic-workflow` Legacy As-Is Mode or Delta Mode.
3. Verify claims against source, tests, docs, accepted specs, configs, or user-provided evidence.
4. Only plan implementation after the As-Is and Delta are clear enough for the risk level.
5. Use OpenSpec when the project requires recorded changes or when behavior/contracts/workflows will change.

### Pure Technical Small Fix

Use this path only when the task does not alter:

- user-visible behavior
- business rules
- data meaning
- API contracts
- permissions
- payments
- notifications
- state transitions
- external integrations

For pure technical small fixes:

1. Confirm the change is behavior-neutral.
2. Follow the project’s required OpenSpec, tests, and docs policy.
3. Skip a full business logic brief unless uncertainty appears.

If the fix affects behavior or contracts, route through New Requirement or Legacy Change instead.

### Project Index Sync

If `ai-project-index` is installed, refresh it after changes to:

- source files
- tests
- docs
- accepted specs or active OpenSpec changes
- project policy files
- skill files

Use the index for discovery, not truth. Read original files before making behavior claims.

### Plugin Recommendations

Based on evaluation of the `claude-plugins-official` marketplace (and a couple of external marketplaces), classify plugin suggestions during `init` into four tiers. Do not suggest anything outside this list without re-evaluating it first.

**Mandatory (always suggest, regardless of detected stack)**
- `context7`: real-time, version-specific library documentation lookup. Low risk, broadly useful.
- `skill-creator`: scaffolding help for building new skills, matching this repo's actual purpose.
- `hookify`: lets you create hooks from plain-language descriptions or simple markdown files instead of hand-writing `settings.json` hook config. Also the recommended mechanism for "Hook Recommendations" below.

**Stack-specific (offer as a multi-select only when the corresponding signal is detected)**
| Detected signal | Candidate plugins |
|---|---|
| PHP/Laravel (`composer.json` has `laravel/framework`) | `laravel-boost`, `php-lsp` |
| Python (`requirements.txt`/`pyproject.toml`) | `pyright-lsp` |
| Frontend framework (`package.json`) | `figma`, `frontend-design`, `typescript-lsp`, `playwright`, `chrome-devtools-mcp` |
| Prisma (`schema.prisma`) | `prisma` |

Never suggest a stack-specific plugin when its signal is absent.

**Conditional (ask explicitly, and state the caveat — never present as an unconditional recommendation)**
- `security-guidance`: three-layer review (free per-edit pattern match; a background model review after each turn that changed files; a deeper agentic review on `git commit`/`git push`, capped at 20/hour). The per-turn and per-commit layers consume real model usage and **no published token-cost benchmark exists**. Recommend a short trial with actual usage measurement (`/costs` or a usage monitor) before keeping it long-term.
- `claude-md-management`: no hooks, only triggered on request (`/revise-claude-md`, or asking it to audit). Low risk to install, but its notion of a "good CLAUDE.md" is generic — it does not know this repo's `development-workflow` template structure or OpenSpec conventions. Review its suggestions before applying them.

**Excluded (do not proactively suggest; explain the reason if asked)**
| Plugin | Reason |
|---|---|
| `code-review`, `code-simplifier` | Overlaps with this project's built-in `/code-review` and `/simplify` skills |
| `feature-dev` | Most of its 7 phases produce conversational, non-persistent output, unlike OpenSpec's versioned artifacts — conflicts with this project's "all changes recorded via OpenSpec" rule |
| `ralph-loop` | Unattended repeated execution conflicts with "discuss and confirm before implementing" |
| `mgrep`, `claude-context` (external marketplaces) | Code content is uploaded to a third-party service (Mixedbread / OpenAI+Zilliz); no viable local-only setup found |

**Already-installed and conflict handling**

Before presenting any of the tiers above, cross-check candidates against `enabledPlugins` and any recorded "Plugin Decisions":

- If a mandatory, stack-specific, or conditional candidate is already installed, do not suggest installing it again — list it under an "already installed" status instead.
- If a plugin from the excluded tier is detected as already installed, surface a one-line conflict note stating the exclusion reason from the table above. Do not suggest uninstalling or disabling it — that decision belongs to the user.

After the user confirms an initialization plan that includes plugin recommendations, record each plugin's resulting status (`installed`, `declined`, or `excluded-conflict-noted`) in a "Plugin Decisions" section of `AGENTS.md` or `CLAUDE.md`, so a future `init` run can read it back instead of starting from zero.

### Hook Recommendations

If `hookify` is installed or being recommended as part of the mandatory tier, suggest using it (instead of hand-written `settings.json` hooks) to encode two rules that are currently only prose reminders elsewhere in this skill:

- **Index refresh**: warn or trigger when `skills/**/SKILL.md`, `AGENTS.md`, or `CLAUDE.md` are edited, reminding to refresh `.ai-project-index` (see "Project Index Sync").
- **Pre-commit OpenSpec check**: warn before `git commit` when an active (non-archived) OpenSpec change exists under `openspec/changes/`, reminding to run `openspec validate --strict` first.

Do not create any hook configuration file as part of `init` itself. Whether to install `hookify` and whether these rules should `warn` or `block` is the user's decision.

## Init Output Shape

Before editing files, show:

```markdown
## Development Workflow Init Plan

Project type: <detected type>
Existing policy files: <found/missing>
OpenSpec: <found/missing/recommended?>
Detected stack signals: <PHP/Laravel, Python, frontend, Prisma — list what was detected>
Plugin recommendations:
- Mandatory: <list>
- Stack-specific (confirm): <list>
- Conditional (caveat applies): <list>
- Already installed (skipped): <list>
- Excluded-tier conflicts detected: <list, with reason>
Recommended skills:
- <skill>: <reason>

Files to create/update:
- <path>: <reason>

Assumptions:
- <assumption>

Needs confirmation:
- <question or decision>
```

After confirmation and edits, summarize:

```markdown
## Development Workflow Init Result

Created/updated:
- <path>

Installed or recommended skills:
- <skill>

Installed or recommended plugins:
- <plugin>

Plugin Decisions recorded in AGENTS.md/CLAUDE.md: <yes/no>

Next workflow:
- New requirement: <route>
- Legacy/refactor: <route>
- Small technical fix: <route>
- After commit: <sync/update rule>
```

## Template Use

When writing `AGENTS.md` or `CLAUDE.md`:

- Preserve existing project-specific rules.
- Keep the final files readable by future AI agents.
- Include explicit trigger phrases such as `development-workflow init`.
- Include the skill routing table.
- Include documentation and index refresh responsibilities.
- Do not leave template placeholders unresolved.
