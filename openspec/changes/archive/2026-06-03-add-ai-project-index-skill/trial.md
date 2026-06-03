## Trial Run

Generated at: 2026-06-03

## Commands

```bash
python3 skills/.experimental/ai-project-index/scripts/generate-index.py
python3 skills/.experimental/ai-project-index/scripts/query-index.py "query parameter" --limit 8
python3 skills/.experimental/ai-project-index/scripts/query-index.py "apidog conflict" --limit 8
python3 skills/.experimental/ai-project-index/scripts/audit-index.py
python3 skills/.experimental/ai-project-index/scripts/generate-docs.py
```

## Generated Artifacts

- `.ai-project-index/index.json`: 304 indexed files, 8 skipped files, 1,020,319 bytes.
- `.ai-project-index/audit.json`: 6,510 bytes.
- `docs/generated/project-map.md`: 12,969 bytes.
- `docs/generated/business-logic-draft.md`: 28,568 bytes.

`.ai-project-index/index.json` and `.ai-project-index/audit.json` are ignored local-regenerate artifacts. `.ai-project-index/config.json` is commit-eligible configuration.

## Query Comparison

### Topic: query parameter

Index query top results included:

- `openspec/specs/laravel-openapi-query-parameter-generation/spec.md`
- `tests/laravel_api_docs_query_parameters_test.php`
- `openspec/specs/laravel-api-docs-contract-surface-candidate-inference/spec.md`
- `skills/.curated/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
- `openspec/specs/laravel-openapi-request-validation-enrichment/spec.md`
- `skills/.curated/laravel-api-docs/src/InferCandidates/ControllerParser.php`
- `docs/laravel-api-docs-guided-sync.md`
- `skills/.curated/laravel-api-docs/scripts/gen-subset-openapi.sh`

Direct `rg` with literal query-related terms found:

- `tests/laravel_api_docs_query_parameters_test.php`
- `docs/laravel-api-docs-guided-sync.md`
- `openspec/specs/laravel-openapi-query-parameter-generation/spec.md`

Result: acceptable. The index found the exact accepted spec and test, plus implementation-adjacent generator/parser files that literal search did not surface from this narrow term set.

### Topic: apidog conflict

Index query top results included:

- `openspec/specs/laravel-api-docs-apidog-conflict-sync/spec.md`
- `skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`
- `openspec/specs/apidog-path-strategy-alignment/spec.md`
- `openspec/specs/laravel-api-docs-guided-sync/spec.md`
- `openspec/specs/apidog-folder-aware-upload/spec.md`
- `openspec/specs/cherry-pick-mode/spec.md`
- `docs/laravel-api-docs-guided-sync.md`
- `skills/.curated/laravel-api-docs/SKILL.md`

Direct `rg` with conflict-related terms found:

- `docs/laravel-api-docs-guided-sync.md`
- `skills/.curated/laravel-api-docs/SKILL.md`
- `skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`
- `openspec/specs/laravel-api-docs-guided-sync/spec.md`
- `openspec/specs/laravel-api-docs-apidog-conflict-sync/spec.md`
- `openspec/specs/apidog-path-strategy-alignment/spec.md`

Result: acceptable. The index ranked the conflict spec and upload script first, and included the same core docs/specs as direct search.

## Audit Result

Audit status: `ok`.

Summary:

- fileCount: 304
- duplicatePathCount: 0
- missingIndexedFileCount: 0
- missingExpectedPatternCount: 0
- stale: false

Expected coverage was acceptable for the curated Laravel API docs skill, accepted OpenSpec specs, docs, tests, OpenSpec workflow skills, and guidance files.

## Limitations

- The full `index.json` is about 1 MB and should not be loaded directly into AI context. Agents should use `query-index.py` to return small ranked candidate paths, then read source-of-truth files.
- The index is a routing aid, not a behavior authority. Claims must still be verified against source files, accepted OpenSpec specs, maintained docs, or tests.
- Query ranking is useful but heuristic. Direct `rg` remains a good fallback when exact literals or exhaustive matches matter.
- Generated docs are drafts. The docs generator now omits archived changes, active changes, and generated draft docs from quick-map output to avoid self-reference and historical noise.
