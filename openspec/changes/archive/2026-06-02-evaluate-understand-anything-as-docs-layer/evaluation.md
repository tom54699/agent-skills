## Evaluation Result

Generated with Understand Anything workflow using `--language zh-TW` intent on commit `f3903419d7ff89d76378016ad2feb24fabea430f`.

## Generated Artifacts

- `.understand-anything/knowledge-graph.json`: 764K
- `.understand-anything/intermediate/`: 2.6M
- `.understand-anything/`: 3.5M total during evaluation
- `.understand-anything/config.json`: stores `outputLanguage: zh-TW`
- `.understand-anything/.understandignore`: starter ignore file; docs/tests were intentionally not excluded
- `.understand-anything/fingerprints.json`: local incremental-update baseline
- `.understand-anything/meta.json`: local analysis metadata

Graph summary:

- Files scanned: 287
- File categories: 35 code, 38 config, 203 docs, 11 script
- Nodes: 731
- Edges: 633
- Layers: 8
- Tour steps: 5
- Node types: 203 document, 46 file, 38 config, 322 function, 24 class, 98 module
- Edge types: `contains` only
- Validation: 0 issues, 0 warnings

Domain graph summary:

- Method: Understand Anything `understand-domain` flow, deriving business domains from the existing knowledge graph
- Output: `.understand-anything/domain-graph.json`
- Size: 24K
- Nodes: 35
- Edges: 34
- Node types: 4 domain, 6 flow, 25 step
- Edge types: 6 `contains_flow`, 25 `flow_step`, 3 `cross_domain`
- Domains: Laravel API Documentation Sync, OpenSpec Change Governance, Repository Documentation And Tests, AI Understanding Layer
- Validation: 0 issues, 0 warnings

Important limitation:

- The generated graph did not include `.codex/skills/openspec-*` because the official scanner uses `git ls-files -co --exclude-standard`, and `.codex/` is ignored by `.gitignore`.
- `AGENTS.md` is also ignored by `.gitignore` and was not included; `CLAUDE.md` was included.
- This is a real evaluation finding. The graph must not be treated as complete OpenSpec workflow coverage unless the project changes ignore/tracking policy or the run is scoped to include those files.

## 3.x Comparisons

### 3.1 Laravel API Docs Skill

Coverage is useful for file/module discovery:

- `skills/.curated/laravel-api-docs/` has 42 file-level nodes.
- PHP and shell structure extraction found function/class-level nodes under the curated skill.
- The graph identifies major areas such as `InferCandidates`, `OpenApiGenerator`, bin entrypoints, and shell scripts.

Limitations:

- The summaries are structural and shallow. They identify files, classes, functions, and headings, but do not reliably explain business rules such as strong/weak signal inference, conflict defaults, or post-upload history rules.
- It is useful as an index, not as replacement for `SKILL.md` or accepted OpenSpec specs.

### 3.2 OpenSpec Workflow Skills And Accepted Specs

Accepted specs:

- `openspec/specs/` has 33 file-level nodes.
- Markdown heading extraction captured requirement/scenario headings, so the graph is useful for finding which spec owns a behavior.
- Accepted specs remain source of truth; graph output may summarize/index them but must not override them.

Workflow skills:

- `.codex/skills/openspec-*` has 0 graph nodes in this run because the directory is gitignored.
- The generated layer `OpenSpec Workflow Skills` is therefore empty.
- Future workflow should either unignore/track those skill files or document that Understand Anything runs are incomplete for workflow-skill analysis.

### 3.3 Docs And Tests

Docs:

- `docs/` has 3 file-level nodes.
- `docs/laravel-api-docs-guided-sync.md` is captured as a document with headings and is useful for navigation.
- Human-authored process decisions in docs remain manual source of truth until replaced by accepted specs.

Tests:

- `tests/` has 3 file-level nodes and many function-level nodes.
- Tests are discoverable as behavioral examples for candidate inference, commit-driven flow, and query parameter generation.
- The graph does not infer test assertions deeply enough to replace reading the tests during implementation.

### 3.4 Documentation Classification

Replaceable after verified graph coverage:

- Project map
- File purpose index
- Directory/module overview
- Reading order for repository navigation
- High-level onboarding map

Partially replaceable:

- Current business-flow summaries derived from code
- Analyzer/generator component relationships
- Test coverage orientation
- OpenSpec spec discovery and cross-reference indexes

Must remain manual source of truth:

- Accepted OpenSpec specs
- `SKILL.md` behavior contract for the Laravel API docs skill
- Human business decisions, ADR-like rationale, and external policies
- API sync conflict policy and Apidog operational rules
- Test assertions and fixtures used as behavior evidence

## 4.x Decisions

### 4.1 Knowledge Graph Commit Policy

Decision: `.understand-anything/knowledge-graph.json` should not be committed by default. It should be regenerated locally.

Rationale:

- It is generated, 764K, and contains derived summaries.
- Intermediate output is larger than the final graph and should never be committed.
- A stale graph can mislead agents if treated as source of truth.

Implemented policy:

- `.gitignore` ignores generated `.understand-anything/*`.
- `.understand-anything/.understandignore` and `.understand-anything/config.json` remain commit-eligible as project configuration.
- `.understand-anything/domain-graph.json` is also generated and should follow the same local-regenerate policy unless a future workflow explicitly decides to commit generated domain graphs.

### 4.2 Recommended Understand Anything / OpenSpec Workflow

Recommended future workflow:

1. Use Understand Anything for current-system discovery before proposing a change.
2. Treat generated graph claims as derived context only.
3. Verify important claims against source files, accepted specs, tests, and manual source-of-truth docs.
4. Use OpenSpec to define intended behavior, design, tasks, and acceptance.
5. Implement only after the OpenSpec change is clear.
6. After implementation, regenerate Understand Anything locally if architecture or workflow context changed.
7. If generated understanding conflicts with accepted specs or source files, report the conflict and prefer the source of truth.

Required follow-up for reliable coverage:

- Decide whether `.codex/skills/openspec-*` and `AGENTS.md` should be unignored/tracked or otherwise included before relying on Understand Anything for workflow-skill analysis.

### 4.3 Separate Workflow Skill Change

Decision: create a separate `understand-openspec-workflow` skill change later, but do not create the final workflow skill in this evaluation change.

Reason:

- This evaluation found a real coverage gap around gitignored workflow files.
- The permanent skill should first define how to handle ignored/untracked workflow docs, then encode the discovery -> OpenSpec -> implementation -> local graph regeneration sequence.
