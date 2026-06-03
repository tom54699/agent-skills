## Context

The `ai-project-index` skill can generate `docs/generated/project-map.md` and `docs/generated/business-logic-draft.md`. These are useful review aids, but they are produced from generated index data and should not become formal docs without human review.

## Goals / Non-Goals

**Goals:**

- Keep generated docs available locally.
- Prevent generated docs from appearing as normal commit candidates.
- Keep the policy aligned with the accepted `ai-project-index-skill` spec.

**Non-Goals:**

- Do not delete local generated docs.
- Do not promote generated drafts into reviewed documentation.
- Do not change the doc generation command.

## Decisions

- Add `docs/generated/*` to `.gitignore`.
- Update the accepted spec to state generated docs are local-regenerate by default.
- Keep future promotion of generated drafts as a separate reviewed docs change.

## Risks / Trade-offs

- [Risk] A useful generated draft may be overlooked during commit review -> Mitigation: users can still read local generated files and manually promote reviewed content into normal docs.
