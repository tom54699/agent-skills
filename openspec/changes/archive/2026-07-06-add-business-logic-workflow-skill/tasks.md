## 1. OpenSpec Artifacts

- [x] 1.1 Create proposal for `business-logic-workflow` skill
- [x] 1.2 Redesign scope around Demand Brief, Legacy As-Is, Delta, and Preservation modes
- [x] 1.3 Add delta specs for `business-logic-workflow-skill` and `skill-repo-layout`

## 2. Skill Implementation

- [x] 2.1 Create `skills/business-logic-workflow/SKILL.md`
- [x] 2.2 Define Demand Brief Mode
- [x] 2.3 Define Legacy As-Is Mode
- [x] 2.4 Define Delta Mode
- [x] 2.5 Define Preservation Mode
- [x] 2.6 Define evidence, uncertainty, and output rules
- [x] 2.7 Classify uncertainty into blocking and deferred questions

## 3. No Default Permanent Docs

- [x] 3.1 Do not create `docs/business/` by default
- [x] 3.2 Remove smoke-test business docs from this change
- [x] 3.3 Keep long-term docs as explicit future preservation decisions

## 4. Repo Guidance Updates

- [x] 4.1 Update README or install docs to list `business-logic-workflow`
- [x] 4.2 Update AGENTS/CLAUDE guidance with business docs workflow entrypoint where appropriate
- [x] 4.3 Update `.ai-project-index/config.json` expected coverage for new skill only

## 5. Verification

- [x] 5.1 Run `python3 skills/ai-project-index/scripts/refresh-index.py`
- [x] 5.2 Run `python3 skills/ai-project-index/scripts/evaluate-index.py`
- [x] 5.3 Run `openspec validate add-business-logic-workflow-skill --strict`
- [x] 5.4 Run `openspec validate --all --strict`
- [x] 5.5 Confirm generated/local artifacts remain ignored
- [x] 5.6 Confirm `docs/business/` is not created
