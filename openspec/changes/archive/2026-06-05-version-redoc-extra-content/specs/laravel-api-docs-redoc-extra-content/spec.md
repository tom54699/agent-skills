## MODIFIED Requirements

### Requirement: Redoc generation can optionally render extra markdown content
The system MUST allow guided-sync to include current-run extra markdown content in the generated HTML without mutating `docs/api-docs/openapi.yaml`.

#### Scenario: User does not request extra content
- **WHEN** `gen-html.sh` runs without enabling extra markdown
- **THEN** the generated HTML MUST not render any existing shared `docs/api-docs/redoc/extra.md`
- **AND** the OpenAPI file MUST remain unchanged

#### Scenario: User requests extra content and file exists
- **WHEN** `gen-html.sh` runs with extra markdown enabled and the selected extra markdown file exists
- **THEN** the generated HTML MUST render the markdown content in a predictable extra section
- **AND** the OpenAPI file MUST remain unchanged

#### Scenario: User requests extra content but file is missing
- **WHEN** `gen-html.sh` runs with extra markdown enabled and the selected extra markdown file does not exist
- **THEN** the script MUST fail with a clear error
- **AND** it MUST not generate a partial HTML file

#### Scenario: Current run must explicitly select extra content
- **WHEN** guided-sync prepares to call `gen-html.sh --with-extra`
- **THEN** the LLM MUST first draft or refresh current-run extra markdown, or pass an explicit `--extra-file FILE`
- **AND** it MUST NOT enable `--with-extra` solely because an old `docs/api-docs/redoc/extra.md` exists
