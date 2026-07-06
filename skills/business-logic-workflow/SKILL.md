---
name: business-logic-workflow
description: Use when the user provides a requirement ticket, asks to discuss business logic, asks to understand old or unfamiliar project behavior, asks to refactor behavior safely, or asks to compare old and new business rules. Produces scoped Business Logic Brief, As-Is, To-Be, Delta, evidence, uncertainty, and promotion decisions without requiring OpenSpec, DDD, or permanent docs.
metadata:
  version: "1.0.0"
---

# Business Logic Workflow

Use this skill to understand and organize business logic before changing or documenting a system.

This skill is not a code generator, not a full-project documentation generator, and not tied to OpenSpec. OpenSpec, tests, and long-term docs are possible downstream outputs after the business logic is clarified.

## Core Rules

- Use Traditional Chinese in this repository.
- Do not require DDD, domain events, aggregates, repositories, or bounded-context code structure.
- Do not claim business truth from code summaries, filenames, or `.ai-project-index` alone.
- Use `.ai-project-index` only to find candidate files; read source, tests, docs, specs, or user-provided requirements before making claims.
- Keep every output scoped. Do not summarize the whole project unless the user explicitly asked for that and evidence covers it.
- Mark uncertain claims as `needs-confirmation` or open questions.
- Split uncertainty into blocking questions and deferred questions after each brief, As-Is summary, or Delta.
- Do not create or update permanent business docs unless the user asks to preserve the result.
- Prefer updating existing business docs over creating new ones when preservation is requested.

## Business Logic Signals

Treat these as business logic when they affect user/system outcomes:

- actors and roles
- workflows and state transitions
- rules, limits, eligibility, permissions, pricing, rewards, penalties
- preconditions, triggers, and side effects
- exceptions, failure cases, and recovery rules
- business meaning of data
- external system interactions
- decisions and rationale

Do not treat these alone as business logic:

- framework setup
- file layout
- pure refactors
- formatting
- generated artifacts
- internal implementation details with no business meaning

## Mode Selection

Before writing files, classify the request:

1. **Demand Brief Mode** - user has a requirement ticket, feature idea, or product/gameplay request.
2. **Legacy As-Is Mode** - user wants to understand old or unfamiliar behavior.
3. **Delta Mode** - user wants to change, refactor, or compare old behavior with new requirements.
4. **Promotion Mode** - user wants to preserve confirmed business logic into long-term docs.

If the mode or scope is unclear, ask a short clarifying question before producing artifacts.

## Question Handling

After producing a Business Logic Brief, As-Is Summary, or Delta, classify unresolved points:

- **Blocking Questions** - must be answered before planning, implementation, refactor, migration, testing, or documentation promotion can continue safely.
- **Deferred Questions** - useful to record, but not required for the current task.

Ask the user only the blocking questions immediately. Keep deferred questions in the output so they are not lost.

## Demand Brief Mode

Use when the user brings a new requirement or wants to discuss business logic.

Goal: produce a scoped Business Logic Brief before technical planning.

Include:

- source requirement or user goal
- scope and non-scope
- actors
- To-Be workflow
- To-Be rules and constraints
- examples and edge cases
- acceptance perspectives
- open questions

If the user later asks to implement, the brief can feed OpenSpec, a task plan, tests, or code.

## Legacy As-Is Mode

Use when the user asks what existing behavior does, especially before refactoring.

Workflow:

1. Define the feature, API, module, workflow, bug, or behavior scope.
2. Use `.ai-project-index` for routing if useful.
3. Read direct evidence: source, tests, existing docs, accepted specs, configs.
4. Produce a scoped As-Is summary with evidence and uncertainty.
5. Call out risks for behavior-preserving changes.

Never convert partial investigation into a whole-system business document.

## Delta Mode

Use when new requirements affect existing behavior.

Produce:

- As-Is: current behavior and evidence
- To-Be: desired behavior from requirement/user discussion
- Delta: what changes, what stays the same, risks, migration concerns
- Tests/acceptance perspectives
- open questions

This mode is especially useful before refactors, rewrites, migrations, gameplay balance changes, payments, permissions, state machines, and external integrations.

## Promotion Mode

Use only when the user wants to preserve confirmed logic beyond the current task.

Before writing long-term docs, decide:

- Is this stable and likely to be reused?
- Is it already captured in an existing doc?
- Is it better kept with the current task/change only?
- What is the natural area/module/product grouping?
- What should be updated instead of added?

Default decision: do not promote. Preserve only when the user confirms value.

## Output Status

Use these labels:

- `draft` - working summary from discussion or partial evidence
- `reviewed` - confirmed by the user
- `needs-confirmation` - plausible but not confirmed
- `stale` - known or suspected outdated

## Output Shapes

Use only the sections needed for the task.

### Business Logic Brief

```markdown
# <需求或功能名稱> Business Logic Brief

Status: draft
Generated-by: business-logic-workflow v1.0.0
Scope: <本次範圍>
Source: <需求單、使用者描述、issue、文件>

## 背景與目標
## 範圍與非範圍
## 參與角色
## To-Be 業務流程
## To-Be 業務規則
## 例外與邊界情境
## 驗收觀點
## 待確認問題
### 阻擋問題
### 可延後確認
```

### As-Is Summary

```markdown
# <範圍> As-Is Business Logic

Status: draft
Generated-by: business-logic-workflow v1.0.0
Scope: <調查範圍>

## 已確認舊邏輯
- <規則或流程>
  - Evidence: `<file>`
  - Confidence: high | medium | low

## 阻擋問題
## 可延後確認
## 重構或變更風險
```

### As-Is / To-Be / Delta

```markdown
# <需求或變更> Business Logic Delta

Status: draft
Generated-by: business-logic-workflow v1.0.0
Scope: <變更範圍>

## As-Is
## To-Be
## Delta
## 不變規則
## 風險
## 驗收觀點
## 阻擋問題
## 可延後確認
```

### Promotion Decision

```markdown
## Business Logic Preservation

Decision: not_promoted | update_existing | create_new | pending
Reason: <原因>
Target: <文件路徑或 none>
```

## Evidence Rules

Confirmed claims should cite at least one source:

- requirement ticket or user-confirmed statement
- source file
- test file
- existing docs
- accepted spec or planning artifact

If evidence is missing, write the claim as a question or mark it `needs-confirmation`.
