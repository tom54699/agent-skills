## 1. OpenSpec Artifacts

- [x] 1.1 Create proposal for direct `skills/<skill-name>/` layout
- [x] 1.2 Add design for path migration and non-goals
- [x] 1.3 Add delta specs for `skill-repo-layout` and `ai-project-index-skill`

## 2. Skill Directory Migration

- [x] 2.1 Move `skills/.curated/laravel-api-docs/` to `skills/laravel-api-docs/`
- [x] 2.2 Move `skills/.experimental/ai-project-index/` to `skills/ai-project-index/`
- [x] 2.3 Remove obsolete empty classification directories when safe

## 3. Reference Updates

- [x] 3.1 Update AGENTS/CLAUDE guidance to direct skill paths
- [x] 3.2 Update README and docs references to direct skill paths
- [x] 3.3 Update accepted specs to direct skill paths
- [x] 3.4 Update `.ai-project-index/config.json` expected coverage to direct skill paths

## 4. Regeneration And Verification

- [x] 4.1 Regenerate `.ai-project-index/index.json` and audit after path migration
- [x] 4.2 Regenerate `docs/generated/*` drafts after path migration
- [x] 4.3 Run script syntax checks for moved `ai-project-index` scripts
- [x] 4.4 Run relevant `laravel-api-docs` PHP syntax checks where practical
- [x] 4.5 Verify no active non-archive references remain for `.curated` or `.experimental`
- [x] 4.6 Run `openspec validate simplify-skill-directory-layout --strict`

## 5. Functional Verification

- [x] 5.1 Verify only direct skill paths exist under `skills/<skill-name>/`
- [x] 5.2 Verify no active docs/specs/scripts reference `skills/.curated` or `skills/.experimental`
- [x] 5.3 Verify `skills/ai-project-index/SKILL.md` command examples work from repo root
- [x] 5.4 Verify `.ai-project-index/config.json` expected coverage points to new skill paths
- [x] 5.5 Verify `query-index.py` excludes `skills/ai-project-index/` by default and includes it with `--include-self`
- [x] 5.6 Verify `generate-index.py` categorizes direct skills as `project-skill`
- [x] 5.7 Verify generated docs use new direct paths
- [x] 5.8 Verify `laravel-api-docs` PHP and shell entrypoints still pass syntax checks after move
- [x] 5.9 Run final `openspec validate simplify-skill-directory-layout --strict`
