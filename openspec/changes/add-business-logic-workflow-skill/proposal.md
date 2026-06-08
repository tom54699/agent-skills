## Why

Users often ask AI to understand or discuss business logic before implementation:

- a new requirement ticket needs clarification before planning
- an unfamiliar legacy feature must be understood before refactor
- a change needs old behavior and new behavior compared
- only some confirmed logic should later be preserved as long-term documentation

The repository needs a focused `business-logic-workflow` skill for this business-logic understanding step. It should not be tied to OpenSpec and should not generate permanent docs by default.

## What Changes

- Add a `business-logic-workflow` skill for:
  - Demand Brief Mode
  - Legacy As-Is Mode
  - Delta Mode
  - Promotion Mode
- Require scoped outputs with evidence, uncertainty, and preservation decisions.
- Avoid creating `docs/business/` or any permanent documentation tree by default.
- Keep OpenSpec as an optional downstream consumer, not a dependency of the skill.
- Explicitly avoid DDD-specific architecture assumptions.

## Capabilities

### New Capabilities

- `business-logic-workflow-skill`: Defines the business logic understanding workflow and output shapes.

### Modified Capabilities

- `skill-repo-layout`: Add `business-logic-workflow` as an active direct-path project skill.

## Impact

- Affected files: `skills/business-logic-workflow/SKILL.md`, install/readme guidance, OpenSpec specs.
- No production runtime impact.
- No permanent business documentation scaffold is introduced.
