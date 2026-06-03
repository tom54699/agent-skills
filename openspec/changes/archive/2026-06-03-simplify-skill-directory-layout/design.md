## Context

The repository currently keeps project skills under `skills/.curated/` and `skills/.experimental/`. That structure made sense when distinguishing stable and exploratory skills was the main concern, but it now makes the paths harder to remember and causes guidance files to mention classification details that users do not need.

The current project skills are:

- `skills/.curated/laravel-api-docs/`
- `skills/.experimental/ai-project-index/`

## Goals / Non-Goals

**Goals:**

- Move project skills to direct paths under `skills/<skill-name>/`.
- Update OpenSpec specs so direct skill paths are the accepted layout.
- Update repo guidance and docs to reference direct paths.
- Keep skill runtime behavior unchanged.

**Non-Goals:**

- Do not redesign `laravel-api-docs` behavior.
- Do not implement `.ai-project-index` sync/query improvements in this change.
- Do not add a new maturity classification system.
- Do not remove archived OpenSpec references.

## Decisions

1. Use direct skill paths as the repository default.
   - New paths: `skills/laravel-api-docs/` and `skills/ai-project-index/`.
   - Rationale: direct paths are shorter, easier for users to browse, and easier for agents to query.
   - Alternative considered: keep `.curated` and `.experimental` but hide them in docs.
   - Rejected because the filesystem would still leak the classification and keep path friction.

2. Remove curated/experimental as required directory classes.
   - Rationale: maturity can be described in docs or frontmatter later if needed, without changing path shape.
   - Alternative considered: rename to `stable/` and `labs/`.
   - Rejected because the user explicitly wants no split.

3. Keep the change mostly mechanical.
   - Move folders, update references, update specs, then validate scripts.
   - Any AI index sync/query improvements stay in a later change.

4. Regenerate generated AI index docs after moving.
   - Rationale: generated drafts currently contain old paths.
   - The generated index/audit remain local-regenerate artifacts.

## Risks / Trade-offs

- Existing docs or tests may still reference old paths → mitigate with `rg` before and after the move.
- Skill install documentation may need wording updates → update docs in the same change.
- Moving `laravel-api-docs` changes many command examples and path references → keep behavior unchanged and validate scripts compile/run where practical.
- Archived OpenSpec changes will still contain historical `.curated` / `.experimental` paths → acceptable; archive is historical record.
