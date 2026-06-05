## 1. OpenSpec Artifacts

- [x] 1.1 Add proposal, design, tasks, and delta specs
- [x] 1.2 Validate `version-redoc-extra-content` with strict OpenSpec validation

## 2. Implementation

- [x] 2.1 Update `gen-html.sh` to snapshot current-run extra markdown into formal version output
- [x] 2.2 Include `version_extra_file` in `gen-html.sh` JSON output when applicable
- [x] 2.3 Update `skills/laravel-api-docs/SKILL.md` Step 8/9 to prevent stale shared extra reuse
- [x] 2.4 Update `docs/laravel-api-docs-guided-sync.md` with versioned extra behavior

## 3. Verification

- [x] 3.1 Run targeted `gen-html.sh` smoke tests for no-extra and with-extra behavior
- [x] 3.2 Run `openspec validate version-redoc-extra-content --strict`
- [x] 3.3 Run `openspec validate --all --strict`
- [x] 3.4 Run `git diff --check`
