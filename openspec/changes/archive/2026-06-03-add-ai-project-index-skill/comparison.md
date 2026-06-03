## Comparison: Understand Anything vs AI Project Index

Generated at: 2026-06-03

## Executive Decision

For this repository, AI agents SHOULD use `.ai-project-index` as the default project-understanding entrypoint.

Understand Anything remains useful as an architectural graph/dashboard tool, but this run is less suitable as the default AI routing layer because it misses local workflow guidance, has more historical noise in query results, and produces many auxiliary artifacts that this project does not need for day-to-day AI development.

The two artifacts SHOULD NOT have identical content:

- `.understand-anything/knowledge-graph.json` is a node/edge graph with layers and tour metadata.
- `.ai-project-index/index.json` is a flat, queryable, auditable file catalog for routing an AI agent to source/spec/docs/tests.

## Artifact Shape

| Item | Understand Anything | AI Project Index |
|------|---------------------|------------------|
| Main folder | `.understand-anything/` | `.ai-project-index/` |
| File count in folder | 68 files | 3 files |
| Folder size | 3.6 MB | 1.0 MB |
| Main index | `knowledge-graph.json` | `index.json` |
| Main index size | 764 KB | 1.0 MB |
| Extra artifacts | intermediate batches, tmp scripts, domain graph, meta | audit + config only |
| Graph support | nodes, edges, layers, tour | no graph; flat file entries |
| Query command | skill guidance says grep relevant graph sections | bundled ranked `query-index.py` |
| Audit command | not project-specific in this run | bundled `audit-index.py` |
| Local include control | not proven for ignored workflow files in this run | explicit `includePaths` |
| Generated output policy | ignored/local regenerate | ignored/local regenerate for index/audit; config commit-eligible |

## Schema And Coverage

Understand Anything:

- Top-level keys: `project`, `nodes`, `edges`, `layers`, `tour`, `kind`, `version`.
- Nodes: 731.
- Edges: 633.
- Layers: 8.
- Tour entries: 5.
- Unique `filePath` values: 287.
- Node types: 322 `function`, 203 `document`, 98 `module`, 46 `file`, 38 `config`, 24 `class`.

AI Project Index:

- Top-level keys: `project`, `scan`, `files`, `skipped`, `version`.
- Indexed files: 304.
- Skipped files: 8.
- Categories: 201 `archived-change`, 42 `curated-skill`, 34 `accepted-spec`, 6 `active-change`, 5 `experimental-skill`, 4 `workflow-skill`, 3 `docs`, 3 `tests`, 3 `source`, 3 `config`.
- Languages: 216 `markdown`, 38 `yaml`, 33 `php`, 11 `shell`, 4 `py`, 2 `json`.

Critical path coverage:

| Path | Understand Anything | AI Project Index | Notes |
|------|---------------------|------------------|-------|
| `AGENTS.md` | Missing | Covered | Required by repo collaboration rules |
| `CLAUDE.md` | Covered | Covered | Guidance file |
| `.codex/skills/openspec-apply-change/SKILL.md` | Missing | Covered | Required workflow skill |
| `.codex/skills/openspec-propose/SKILL.md` | Missing | Covered | Required workflow skill |
| `skills/.curated/laravel-api-docs/SKILL.md` | Covered | Covered | Curated skill entrypoint |
| `skills/.curated/laravel-api-docs/bin/infer-candidates.php` | Covered | Covered | Runtime entrypoint |
| `skills/.curated/laravel-api-docs/src/InferCandidates/Analyzer.php` | Covered | Covered | Core analyzer |
| `skills/.curated/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php` | Covered | Covered | Core generator |
| `docs/laravel-api-docs-guided-sync.md` | Covered | Covered | Maintained docs |
| `tests/laravel_api_docs_query_parameters_test.php` | Covered | Covered | Test coverage |
| `openspec/specs/project-understanding-layer/spec.md` | Missing in this UA run | Covered | Accepted spec created after UA run; commit hash alone did not reveal this working-tree drift |

Layer observation:

- Understand Anything produced useful layers, but `OpenSpec Workflow Skills` had 0 nodes.
- The AI Project Index intentionally includes `.codex/skills/openspec-*/SKILL.md` through config so this workflow layer is not lost.

## Query Evaluation

Method:

- AI Project Index used `query-index.py "<topic>" --limit 8`.
- Understand Anything was searched using node `id`, `type`, `name`, `filePath`, `summary`, and `tags`, following the `understand-chat` skill guidance to search the graph instead of reading it whole.
- Each topic had three expected high-value paths. A hit means the path appeared in top 8.

| Topic | AI hits | UA hits | Result |
|-------|---------|---------|--------|
| `query parameter` | 3/3 | 2/3 | AI ranked accepted spec, test, and generator; UA was partly buried by archived change files |
| `apidog conflict` | 3/3 | 2/3 | AI ranked accepted spec and upload script first; UA had multiple archived conflict specs first |
| `OpenSpec workflow` | 3/3 | 0/3 | AI found `.codex` workflow skills and `AGENTS.md`; UA missed them |
| `candidate inference` | 0/3 | 0/3 | Both returned specs/history first for this broad concept |
| `OpenAPI generator` | 2/3 | 2/3 | Both worked for clear component naming |
| `sync history` | 2/3 | 2/3 | Both found core sync history spec/script; UA had archive noise |
| `Redoc HTML` | 3/3 | 1/3 | AI found current SKILL/spec/script/docs; UA was dominated by archived Redoc changes |
| `path strategy` | 3/3 | 1/3 | AI found current specs and `PathStrategy.php`; UA ranked archived path-strategy changes |
| `response return analysis` | 3/3 | 1/3 | AI found current spec and source; UA ranked archived change artifacts first |
| `public skill distribution` | 2/3 | 1/3 | AI found current spec/docs; UA ranked archived proposal artifacts first |

Summary:

- AI Project Index won 7 of 10 broad topics.
- The two ties were clear component or shared-domain topics.
- Both tools performed poorly on the broad `candidate inference` query when the expected target was source/test files; a more specific query is needed.
- Understand Anything frequently surfaced archived OpenSpec changes above current accepted specs and source files.

## Source-Specific Follow-up Queries

Broad domain queries often return specs first, which is useful for requirement discovery but not always for implementation. Source-specific queries were tested separately.

| Query | AI top result pattern | UA top result pattern | Result |
|-------|-----------------------|-----------------------|--------|
| `Analyzer candidate inference php` | accepted analyzer spec, `Analyzer.php`, `AnalyzerOptions.php`, tests | `Analyzer.php`, `AnalyzerOptions.php`, analyzer spec | Tie; both good |
| `ControllerParser documentation parameters` | `ControllerParser.php`, query-parameter test/specs | `ControllerParser.php`, test, archived query-parameter changes | AI cleaner |
| `upload apidog shell conflict` | `upload-apidog.sh`, conflict specs | `upload-apidog.sh`, archived conflict/alignment changes | AI cleaner |
| `ResponseAnalyzer return analysis` | response spec, `ResponseAnalyzer.php`, adapters | archived response-analysis change artifacts | AI better |
| `PathStrategy api prefix` | `PathStrategy.php`, related source/specs | `PathStrategy.php`, related source/docs | Tie; both useful |

## Token And Context Cost

Main-index size alone is misleading:

- `knowledge-graph.json`: 764 KB.
- `index.json`: 1.0 MB.

If an AI reads the entire file, neither is ideal. The intended use is targeted query:

- 10 AI Project Index queries with `--json` produced about 99 KB total.
- The same 10 queries with default human-readable output produced about 35 KB total.
- Single default query output was roughly 3 to 4 KB in this run.

For AI agent usage, this is the main advantage of `.ai-project-index`: the agent can run a query command and read small ranked results instead of loading a full index.

Understand Anything can also be queried with grep, but this run does not provide a repo-specific ranking/filter command. Its graph search must be manually scoped, and archived changes often appear before current accepted specs/source files.

## Noise And Freshness

Understand Anything noise observed:

- 68 artifact files in `.understand-anything/`, including intermediate batches and tmp scripts.
- Many query results ranked archived OpenSpec changes above current accepted specs.
- Domain graph/dashboard artifacts exist but were not useful for this repo's AI-only indexing goal.
- `OpenSpec Workflow Skills` layer had 0 nodes.

AI Project Index noise observed:

- The index still includes archived changes as indexed data, which contributes 201 of 304 indexed files.
- Query excludes archives by default, so this usually does not affect agent routing.
- If agents read the full `index.json`, archive volume is still wasteful.
- Future improvement: optionally split archives into a separate index or exclude archives from default generation.

Freshness issue:

- UA project metadata: analyzed at `2026-06-02T06:06:04.460Z`.
- AI Project Index metadata: generated at `2026-06-03T02:14:32+00:00`.
- Both recorded git commit `f3903419d7ff89d76378016ad2feb24fabea430f`.
- Because this repository had uncommitted OpenSpec changes, commit hash alone did not prove the generated artifact matched the current working tree.
- Future improvement: add a working-tree fingerprint to audit output.

## Decision By Use Case

| Use case | Better choice | Reason |
|----------|---------------|--------|
| AI needs quick candidate files before implementation | AI Project Index | Query command returns current source/spec/docs/tests paths with low context |
| AI must follow repo workflow rules | AI Project Index | Includes `AGENTS.md` and `.codex/skills/openspec-*` |
| Human wants visual architecture exploration | Understand Anything | Has graph, layers, tour, dashboard support |
| AI wants relationship graph traversal | Understand Anything | Has nodes and edges |
| AI wants current source-of-truth routing | AI Project Index | Less archive noise and project-specific audit |
| Verifying business behavior | Neither alone | Read source files, accepted specs, maintained docs, and tests |

## Recommendation

Use `.ai-project-index` as the default AI development aid for this repository.

Recommended flow:

1. Regenerate `.ai-project-index/index.json` after meaningful source/spec/docs/test changes.
2. Run `.ai-project-index/audit.json` before relying on the index.
3. Query with `query-index.py` for candidate paths.
4. Read original source-of-truth files before making behavior claims.
5. Use Understand Anything only when graph/layer/tour visualization is specifically useful.

Do not replace source files, accepted OpenSpec specs, maintained docs, or tests with either generated artifact.

## Follow-up Improvements

- Add working-tree fingerprinting to `audit-index.py`.
- Add an option to exclude archived OpenSpec changes from default index generation, or split them into a separate archive index.
- Add a query mode that can bias toward `source`, `accepted-spec`, `docs`, or `tests`.
- Consider a small project command wrapper for common queries instead of asking agents to remember script paths.
