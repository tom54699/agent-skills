## MODIFIED Requirements

### Requirement: HTML extra content is prompted in user-facing language
The system MUST ask about HTML extra content in user-facing language before referring to `extra.md`.

#### Scenario: User wants HTML output
- **WHEN** Step 7 completes and the user chooses to generate HTML
- **THEN** the system MUST ask whether the HTML page should include additional explanatory content
- **AND** MUST NOT use `extra.md` as the primary user-facing concept

#### Scenario: User wants additional HTML content
- **WHEN** the user asks for additional HTML page content
- **THEN** the system MUST discuss and draft that content before generating HTML
- **AND** MUST store the drafted content in `docs/api-docs/redoc/extra.md`
