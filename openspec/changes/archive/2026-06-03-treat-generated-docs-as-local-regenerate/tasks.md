## 1. Policy

- [x] 1.1 Update `.gitignore` so `docs/generated/*` is local-regenerate by default
- [x] 1.2 Update accepted `ai-project-index-skill` spec with generated docs commit policy
- [x] 1.3 Verify generated docs are ignored while the directory can still exist locally

## 2. Verification

- [x] 2.1 Run `openspec validate treat-generated-docs-as-local-regenerate --strict`
- [x] 2.2 Run `openspec validate --all --strict`
- [x] 2.3 Confirm `git status` no longer shows `docs/generated/*` as untracked commit candidates
