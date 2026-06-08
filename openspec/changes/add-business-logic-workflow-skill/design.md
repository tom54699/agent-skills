## Context

The first draft drifted toward a permanent `docs/business/` taxonomy. That does not match the expected usage.

The common user situations are:

1. New requirement discussion: produce business logic before technical planning.
2. Legacy understanding: inspect unfamiliar code/docs/tests to understand current behavior.
3. Change/refactor comparison: compare As-Is and To-Be business logic before implementation.

Long-term documentation is a later preservation decision, not the default output.

## Goals / Non-Goals

**Goals:**

- Define a business-logic understanding workflow independent of OpenSpec.
- Support requirement-ticket, legacy As-Is, and As-Is/To-Be/Delta workflows.
- Require evidence and uncertainty markings.
- Keep outputs scoped and temporary by default.
- Provide a preservation decision step for long-term docs.
- Keep the process architecture-neutral and usable for Flutter apps, backend services, scripts, Laravel projects, and mixed legacy projects.

**Non-Goals:**

- Do not create `docs/business/` by default.
- Do not create a long-term documentation taxonomy in this change.
- Do not require OpenSpec before using the skill.
- Do not generate final business docs from code alone.
- Do not introduce DDD architecture requirements.
- Do not create a `development-workflow` skill in this change.

## Decisions

### Decision: Business logic workflow is independent

The skill handles business logic understanding. OpenSpec can consume the result later, but is not required.

### Decision: Default output is scoped and temporary

The default outputs are Business Logic Brief, As-Is Summary, or Delta. They may be returned in conversation or written to a user-confirmed path. They are not automatically promoted to permanent docs.

### Decision: Preservation is explicit

Before writing long-term docs, the AI must make a preservation decision:

- `not_promoted`
- `update_existing`
- `create_new`
- `pending`

Default is `not_promoted` unless the user confirms value.

### Decision: Evidence and uncertainty are mandatory

As-Is claims must cite direct evidence such as source, tests, docs, specs, or user-confirmed statements. Missing evidence becomes `needs-confirmation` or an open question.

## Risks / Trade-offs

- [Risk] Users may expect a file every time -> Mitigation: skill says default output can remain scoped conversation output unless user asks to write it.
- [Risk] AI may over-document -> Mitigation: no permanent docs by default and preservation decision required.
- [Risk] AI may overstate legacy behavior -> Mitigation: evidence and confidence required for As-Is claims.
