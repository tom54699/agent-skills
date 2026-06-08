## 1. Skill Structure

- [x] 1.1 Create `skills/development-workflow/` with required `SKILL.md`
- [x] 1.2 Add reusable `AGENTS.md` and `CLAUDE.md` templates under `skills/development-workflow/assets/`

## 2. Workflow Definition

- [x] 2.1 Document `development-workflow init` behavior, including project inspection, initialization plan, confirmation, and policy-file update rules
- [x] 2.2 Document skills routing for new requirements, legacy/refactor work, project understanding, OpenSpec changes, and lightweight technical fixes
- [x] 2.3 Ensure the skill references specialized skills without duplicating their full workflows

## 3. Repo Documentation

- [x] 3.1 Update `README.md` to list `development-workflow` and its install command
- [x] 3.2 Update `docs/install-skills.md` to include `development-workflow`
- [x] 3.3 Update `AGENTS.md` and `CLAUDE.md` project guides to include the new development workflow reading order

## 4. Index And Validation

- [x] 4.1 Update `.ai-project-index/config.json` so the new skill and templates are indexed appropriately
- [x] 4.2 Run `.ai-project-index` refresh/evaluation if available and inspect results
- [x] 4.3 Run OpenSpec strict validation for the change and all specs
- [x] 4.4 Run `git diff --check`
