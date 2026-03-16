## ADDED Requirements

### Requirement: Public install docs use the canonical repository slug
The repository MUST document public installation using the repository's canonical public slug.

#### Scenario: User reads the README install section
- **WHEN** the user opens the repository on GitHub
- **THEN** the install command MUST use the actual public slug
- **AND** public links in README MUST work on GitHub without relying on local filesystem paths

### Requirement: Public distribution guidance is documented
The repository MUST provide a publication guide for making the skill repo publicly installable.

#### Scenario: Maintainer prepares the repo for public release
- **WHEN** the maintainer checks the publication guide
- **THEN** the guide MUST describe the intended repository name, visibility, and install command
- **AND** MUST include a concrete pre-release checklist for public distribution

### Requirement: Internal experimental skills are documented
The repository MUST document how experimental skills can be hidden from normal installation.

#### Scenario: Experimental skill should stay hidden
- **WHEN** a maintainer adds an experimental skill that should not appear in normal discovery
- **THEN** the guide MUST instruct them to set `metadata.internal: true` in `SKILL.md`
- **AND** MUST explain that `INSTALL_INTERNAL_SKILLS=1` is required to list or install that skill
