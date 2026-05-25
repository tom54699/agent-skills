## 1. Versioned Output Implementation

- [x] 1.1 Update `preflight.sh` to prepare `docs/api-docs/versions/`.
- [x] 1.2 Update `gen-html.sh` to create a unique version folder for formal Redoc output.
- [x] 1.3 Copy the current OpenAPI snapshot and generated `index.html` / `api-docs.html` into the version folder.
- [x] 1.4 Ensure custom `--output` paths do not create official version folders.

## 2. Workflow Documentation

- [x] 2.1 Update `SKILL.md` directory conventions, outputs, and Step 9 flow.
- [x] 2.2 Update `docs/laravel-api-docs-guided-sync.md` with latest-entry and version-snapshot behavior.

## 3. Verification

- [x] 3.1 Run shell syntax checks for changed scripts.
- [x] 3.2 Run a representative `gen-html.sh` generation against a sample OpenAPI file and verify latest files plus version snapshot.
- [x] 3.3 Run a custom-output generation and verify it does not create an official version snapshot.
