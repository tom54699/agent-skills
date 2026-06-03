## Context

This repository is a skill repository with OpenSpec-managed changes and a curated Laravel API documentation skill. The user wants future feature development to continue using OpenSpec, while using Understand Anything to replace repetitive hand-written AI navigation rules and possibly some current-system documentation.

Understand Anything is an external tool that generates a project knowledge graph and related understanding artifacts. OpenSpec remains the workflow for defining intended changes, tasks, and accepted behavior.

## Goals / Non-Goals

**Goals:**

- Install or enable Understand Anything for Codex in the local environment.
- Run Understand Anything against this repository in Traditional Chinese where supported.
- Inspect generated artifacts for usefulness and accuracy.
- Classify existing documentation into replaceable, partially replaceable, and must-remain-manual categories.
- Capture the resulting workflow decisions before designing a permanent skill.

**Non-Goals:**

- Do not remove existing docs during the first evaluation run.
- Do not make `.understand-anything/knowledge-graph.json` a committed artifact until size, content, and usefulness are reviewed.
- Do not create the final `understand-openspec-workflow` skill in this change.
- Do not change the Laravel API docs guided-sync runtime behavior.

## Decisions

1. Treat Understand Anything as a current-system understanding layer, not as the OpenSpec replacement.
   - Alternative considered: replace OpenSpec with generated graph output.
   - Rejected because OpenSpec defines intended future behavior and reviewable change scope, while graph output is derived from current files.

2. Evaluate docs replacement by category.
   - Replaceable candidates: project map, module overview, reading order, file purpose, dependency overview, onboarding.
   - Partial candidates: current business flow derived from code.
   - Must-remain candidates: human business decisions, ADRs, external policies, and accepted OpenSpec specs.

3. Keep graph commit policy undecided until after the first run.
   - Alternative considered: always commit `.understand-anything/knowledge-graph.json`.
   - Rejected for now because generated output may be large or contain noisy derived summaries.

4. Use the evaluation result to design the workflow skill later.
   - Alternative considered: create the workflow skill immediately.
   - Rejected because the skill should be based on the actual tool output and limitations observed in this repo.

## Risks / Trade-offs

- Generated understanding may be inaccurate or stale -> verify key claims against actual docs, OpenSpec specs, and code.
- Generated graph may be too large for practical version control -> inspect size and decide commit policy before adding it.
- Generated business logic may appear authoritative -> label it as derived understanding unless backed by docs or accepted specs.
- Installation may require network and writes outside the repo -> use explicit approval before installing.
