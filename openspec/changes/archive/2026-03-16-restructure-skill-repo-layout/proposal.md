## Why

這個 repo 接下來會持續新增多個 skill，但目前 `skills/` 還是平鋪結構，無法直接表達哪些 skill 已穩定可安裝、哪些仍在試驗中。另一方面，README 也還停留在自用 repo 的描述，沒有明確說明 repo-based skill 安裝方式。

若現在不先整理，之後 skill 數量增加時，安裝入口、成熟度分層與文件維護都會變得混亂。

## What Changes

- 將 `skills/` 調整為多 skill repo 結構，新增 `.curated/` 與 `.experimental/` 分層。
- 將目前穩定的 `laravel-api-docs` 移入 `skills/.curated/laravel-api-docs`。
- 補上 repo 級安裝與結構文件，說明以 GitHub repo 配合 `npx skills add <repo>` 的使用方式。
- 同步更新 repo 內仍在使用的引用路徑，避免活的 OpenSpec 與 README 指向舊位置。

## Capabilities

### Added Capabilities
- `skill-repo-layout`: repo MUST 區分穩定可安裝與實驗中 skill，並提供一致的安裝入口說明。

### Modified Capabilities
- `laravel-api-docs-distribution`: `laravel-api-docs` MUST 以 curated skill 的位置對外提供。

## Impact

- 影響 `README.md`
- 新增 `docs/install-skills.md`
- 影響 `skills/.curated/laravel-api-docs` 的實體位置
- 影響非 archive 的 `openspec/changes/**` 內 skill 路徑引用
