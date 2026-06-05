## Why

`laravel-api-docs` already creates timestamped Redoc version snapshots, but optional HTML extra content is still read from the shared `docs/api-docs/redoc/extra.md` path.
This can make a new HTML generation accidentally reuse previous-run notes when `extra.md` was not refreshed.

## What Changes

- Preserve the exact extra markdown used for a formal Redoc generation inside the same `docs/api-docs/versions/<version-id>/` snapshot.
- Update guided-sync instructions so extra content must be drafted or explicitly selected for the current run before `--with-extra` is used.
- Keep `docs/api-docs/redoc/` as the latest stable output path.
- Keep OpenAPI unchanged by extra content.

## Impact

- Affected files: `skills/laravel-api-docs/SKILL.md`, `skills/laravel-api-docs/scripts/gen-html.sh`, `docs/laravel-api-docs-guided-sync.md`, OpenSpec delta specs.
- No production runtime impact outside the local skill workflow.
