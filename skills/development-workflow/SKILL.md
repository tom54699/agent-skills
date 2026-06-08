---
name: development-workflow
description: Use when the user asks to initialize a project workflow, run `development-workflow init`, define AI collaboration rules, create AGENTS.md/CLAUDE.md, decide which workflow skill to use, or coordinate business logic, OpenSpec, project index, docs, tests, and implementation steps.
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
2. Produce an initialization plan before editing:
   - files to create or update
   - skills to install or verify
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

## Init Output Shape

Before editing files, show:

```markdown
## Development Workflow Init Plan

Project type: <detected type>
Existing policy files: <found/missing>
OpenSpec: <found/missing/recommended?>
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
