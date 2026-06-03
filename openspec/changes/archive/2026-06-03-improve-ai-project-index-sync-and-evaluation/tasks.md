## 1. Refresh Workflow

- [x] 1.1 Define the manual refresh sequence in `skills/ai-project-index/SKILL.md`
- [x] 1.2 Add or document a single refresh command that runs index generation and audit in order
- [x] 1.3 Document when refresh is expected after source, spec, docs, tests, guidance, or skill changes
- [x] 1.4 Confirm generated `.ai-project-index` artifacts remain local-regenerate outputs

## 2. Audit Improvements

- [x] 2.1 Verify audit warning behavior for stale git commit metadata
- [x] 2.2 Verify audit warning behavior for indexed paths that no longer exist
- [x] 2.3 Verify audit warning behavior for missing expected coverage patterns
- [x] 2.4 Verify audit warning behavior for empty or structurally invalid index output where practical
- [x] 2.5 Update audit output or documentation so agents know when not to rely on the index

## 3. Evaluation Harness

- [x] 3.1 Define reusable evaluation cases with query, expected paths, and direct-read comparison scope
- [x] 3.2 Add approximate token estimation for direct inspection versus index-assisted inspection
- [x] 3.3 Record whether index-assisted discovery returns expected source-of-truth paths
- [x] 3.4 Record missed paths and direct-source fallback cases
- [x] 3.5 Write evaluation output to a reviewed markdown or JSON artifact under `docs/` or `.ai-project-index/`

## 4. Functional Test Cases

- [x] 4.1 Test Laravel API docs candidate inference discovery
- [x] 4.2 Test OpenAPI generation discovery
- [x] 4.3 Test OpenSpec workflow skill discovery
- [x] 4.4 Test accepted spec discovery
- [x] 4.5 Test docs discovery
- [x] 4.6 Test tests discovery
- [x] 4.7 Test generated docs discovery policy
- [x] 4.8 Test archived change discovery with default exclusion and explicit inclusion
- [x] 4.9 Test ai-project-index self-discovery with default exclusion and `--include-self`

## 5. AI Usage Guidance

- [x] 5.1 Update `skills/ai-project-index/SKILL.md` with rules for query-first broad discovery
- [x] 5.2 Document that source files, accepted specs, reviewed docs, and tests remain authoritative
- [x] 5.3 Document stale-audit behavior and when agents should refresh before using the index
- [x] 5.4 Document when direct source reading is preferable to index-assisted discovery

## 6. Verification

- [x] 6.1 Regenerate `.ai-project-index/index.json`
- [x] 6.2 Run `.ai-project-index` audit and confirm expected status
- [x] 6.3 Run evaluation cases and inspect results
- [x] 6.4 Run relevant Python syntax checks for `skills/ai-project-index/scripts/*.py`
- [x] 6.5 Run `openspec validate improve-ai-project-index-sync-and-evaluation --strict`
- [x] 6.6 Decide whether a follow-up change should add optional hook or workflow automation
