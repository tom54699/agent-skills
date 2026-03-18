## ADDED Requirements

### Requirement: Candidate inference SHALL tolerate unresolved symbol lookups
The system MUST treat unresolved controller/request/resource/service/exception file lookups as a non-fatal miss during candidate inference.

#### Scenario: Resolver cannot find a related class file
- **WHEN** candidate inference attempts to resolve a related class and no matching file is found
- **THEN** the resolver returns an empty result without aborting the script
- **AND** candidate inference continues processing remaining endpoints

### Requirement: Candidate inference SHALL still write output after tolerated misses
When inference completes despite unresolved lookups, the system MUST still produce the final JSON result and write the requested output file.

#### Scenario: User passes output path
- **WHEN** the user runs `infer-candidates.sh --output /tmp/candidates.json`
- **THEN** the script writes the final result JSON to `/tmp/candidates.json` as long as no fatal error occurs outside tolerated resolver misses
