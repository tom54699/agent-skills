## MODIFIED Requirements

### Requirement: Skill SHALL use a single guided-sync mode
`laravel-api-docs` skill MUST provide one execution mode named `guided-sync` and MUST NOT require users to choose among multiple generation modes during normal use.

#### Scenario: User triggers API docs sync
- **WHEN** user says phrases such as `幫我產生 API 文件`, `更新 API 文件`, `文件同步`, or `sync api docs`
- **THEN** the skill executes `guided-sync` flow without presenting mode selection options
- **AND** the running flow presents observable progress for the current guided-sync step

### Requirement: Skill SHALL require user confirmation on the final endpoint list
The skill MUST present a candidate endpoint list and MUST confirm the final target list with the user before deep analysis and document update.

#### Scenario: Candidate list has mistakes
- **WHEN** the user modifies candidate endpoints (add/remove/reclassify)
- **THEN** the skill updates the target list and only processes the confirmed list
- **AND** the guided-sync flow keeps showing workflow progress while waiting for the next executable step
