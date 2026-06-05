## Context

The current `gen-html.sh` supports:

- `--with-extra`
- `--extra-file FILE`
- formal latest output under `docs/api-docs/redoc/`
- formal snapshots under `docs/api-docs/versions/<version-id>/`

However, the default extra path is shared: `docs/api-docs/redoc/extra.md`.
The version snapshot does not currently copy the extra markdown source, so readers cannot tell which extra content produced a historical `index.html`.

## Design

### Versioned extra snapshot

When formal output is generated to the default Redoc path and `--with-extra` is enabled, `gen-html.sh` will copy the rendered markdown source into:

```text
docs/api-docs/versions/<version-id>/redoc/extra.md
```

The generated JSON result will include:

- `extra_file`: the source extra file used for rendering
- `version_extra_file`: the snapshot path, only when a formal version was created with extra content

### Current-run extra rule

The skill workflow should treat `docs/api-docs/redoc/extra.md` as the latest editable draft, not as reusable historical truth.
Before invoking `gen-html.sh --with-extra`, the LLM must either:

- write current-run content to `docs/api-docs/redoc/extra.md`, or
- pass an explicit current-run file via `--extra-file FILE`

If the user chooses no extra content, the workflow must run without `--with-extra`, even if an old `extra.md` exists.

### Compatibility

The existing CLI flags remain valid.
Existing callers using `--with-extra` still work, but formal snapshots become more traceable.

## Risks / Trade-offs

- The shared latest `extra.md` remains in place for compatibility and editing convenience.
- Avoiding stale content still depends on workflow discipline when callers explicitly pass `--with-extra`; the skill guidance is updated to make that requirement clear.
