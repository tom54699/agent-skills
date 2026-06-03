## 1. Skill Structure

- [x] 1.1 Create `skills/.experimental/ai-project-index/` with `SKILL.md`
- [x] 1.2 Add bundled scripts for generate, query, audit, and optional docs draft generation
- [x] 1.3 Ensure generated `.ai-project-index/` artifacts are ignored by version control while keeping any intentional config commit-eligible

## 2. Index Generation

- [x] 2.1 Implement deterministic repository scanning with support for configured local-only include paths
- [x] 2.2 Extract compact metadata for files, Markdown headings, PHP classes/functions, shell functions, YAML/JSON keys, tags, and searchable text
- [x] 2.3 Write `.ai-project-index/index.json` with project metadata, file entries, generation metadata, and source coverage stats

## 3. Query And Audit

- [x] 3.1 Implement a query command that returns ranked candidate paths and short match context without dumping the full index
- [x] 3.2 Implement default filtering of archived OpenSpec changes with an option to include them
- [x] 3.3 Implement an audit command for expected coverage and basic index integrity
- [x] 3.4 Ensure audit reports missing `.codex/skills/openspec-*` and guidance files when they are not indexed

## 4. Optional Documentation Drafts

- [x] 4.1 Implement generated project map draft output under `docs/generated/project-map.md`
- [x] 4.2 Implement generated business logic draft output under `docs/generated/business-logic-draft.md`
- [x] 4.3 Label generated docs clearly as drafts requiring review

## 5. Trial Run And Evaluation

- [x] 5.1 Run the new skill against this repository
- [x] 5.2 Query at least two known topics and compare results against direct `rg` discovery
- [x] 5.3 Run audit and record whether expected coverage is acceptable
- [x] 5.4 Record trial results and any limitations in the OpenSpec change

## 6. Validation

- [x] 6.1 Validate the OpenSpec change with `openspec validate add-ai-project-index-skill --strict`
- [x] 6.2 Review generated artifacts and confirm no generated index output is staged for commit by default

## 7. Comparative Evaluation

- [x] 7.1 Compare `.understand-anything/knowledge-graph.json` against `.ai-project-index/index.json`
- [x] 7.2 Evaluate coverage, query quality, noise, artifact size, and AI usage cost across multiple topics
- [x] 7.3 Record comparison results and recommendation in `comparison.md`
