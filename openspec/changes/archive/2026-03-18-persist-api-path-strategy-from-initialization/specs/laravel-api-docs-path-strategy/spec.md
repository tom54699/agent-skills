## ADDED Requirements

### Requirement: Guided sync MUST use an explicit API path strategy
The system MUST normalize Laravel route paths according to an explicit project-level API path strategy instead of assuming the `api` prefix is always removed.

#### Scenario: Keep full path strategy preserves api prefix
- **WHEN** project path strategy is `keep-full-path`
- **THEN** route normalization MUST preserve Laravel route paths such as `/api/admin/login`

#### Scenario: Strip api prefix strategy moves prefix to server base path
- **WHEN** project path strategy is `strip-api-prefix-to-server`
- **THEN** route normalization MUST convert Laravel route paths such as `/api/admin/login` into `/admin/login`
- **AND** generated OpenAPI server configuration MUST carry the `/api` base path

### Requirement: Analyzer and generator MUST share the same path strategy
The system MUST apply the same path strategy to candidate inference and OpenAPI generation.

#### Scenario: Candidate keys and generated paths stay aligned
- **WHEN** a project has chosen a path strategy
- **THEN** candidate route keys and generated OpenAPI paths MUST be normalized using that same strategy

### Requirement: Path strategy MUST be observable
The system MUST expose the active path strategy in project-facing metadata or debug output so users can verify which route representation is in effect.

#### Scenario: Debug output shows active strategy
- **WHEN** candidate inference or generation runs with debug/meta output enabled
- **THEN** the output MUST indicate the active path strategy

