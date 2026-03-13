## MODIFIED Requirements

### Requirement: HTML output uses a dedicated summary home page
The system MUST render extra HTML content in a dedicated summary home page instead of a raw top-of-page block.

#### Scenario: HTML is generated with extra content
- **WHEN** the HTML generator runs with `--with-extra`
- **THEN** the output MUST generate `index.html` for the extra content
- **AND** MUST generate a separate `api-docs.html` for the Redoc API reference

#### Scenario: HTML is generated without extra content
- **WHEN** the HTML generator runs without `--with-extra`
- **THEN** the output MUST still generate `index.html`
- **AND** `index.html` MUST act as the consistent landing page for the HTML docs

### Requirement: Markdown tables remain readable in HTML output
The system MUST render Markdown tables from extra content into readable HTML tables.

#### Scenario: Extra content includes a pipe table
- **WHEN** `extra.md` contains a Markdown table
- **THEN** the rendered HTML MUST include a `<table>` representation instead of flattening the rows into plain paragraphs
