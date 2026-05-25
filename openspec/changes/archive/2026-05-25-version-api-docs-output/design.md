## Context

`gen-html.sh` 目前將 Redoc 輸出固定寫到 `docs/api-docs/redoc/index.html` 與 `docs/api-docs/redoc/api-docs.html`，每次執行都會覆蓋前一次 HTML。`docs/api-docs/openapi.yaml` 仍是 Apidog 同步唯一來源，也會持續代表最新版。

這次變更需要在不破壞既有固定入口的前提下，為每次 HTML 生成保存一份 OpenAPI 與 Redoc HTML 快照。

## Goals / Non-Goals

**Goals:**
- 每次 guided-sync 產生 HTML 時建立一個版本資料夾。
- 版本資料夾保留本次 `openapi.yaml` 與兩頁 Redoc HTML。
- `docs/api-docs/redoc/` 仍維持最新版固定入口。
- 流程文件明確告知最新版入口與版本備份位置。

**Non-Goals:**
- 不改變 Apidog 同步來源；仍只使用 `docs/api-docs/openapi.yaml`。
- 不新增版本清理、保留天數、索引頁或差異比對功能。
- 不改變 OpenAPI generator 的 merge 規則。

## Decisions

1. 版本資料夾路徑固定為 `docs/api-docs/versions/<version-id>/`。

   `<version-id>` 使用本機時間 `YYYYMMDD-HHMMSS`。若同一秒內已存在同名資料夾，依序使用 `YYYYMMDD-HHMMSS-2`、`YYYYMMDD-HHMMSS-3` 避免覆蓋。

2. `gen-html.sh` 先照現有方式產出最新版，再複製到版本資料夾。

   這保留既有固定入口，也讓版本備份與使用者實際看到的最新版 HTML 內容一致。複製內容包含：
   - `docs/api-docs/openapi.yaml` 的當下快照
   - `index.html`
   - `api-docs.html`

3. 版本化預設只套用正式 Redoc 輸出。

   當 `--output` 指向預設正式位置 `docs/api-docs/redoc/api-docs.html` 時，自動建立版本備份。非正式輸出路徑保留原本彈性，避免 cherry-pick 或臨時輸出污染正式版本庫。

4. Preflight 建立 `docs/api-docs/versions/`。

   這讓 guided-sync 的目錄準備與文件慣例一致，不需要等 HTML 生成時才隱式建立根目錄。

## Risks / Trade-offs

- [磁碟空間累積] 每次 HTML 生成都保留快照，長期可能增加 repository 或工作目錄大小 → 先不自動清理，後續可獨立設計保留策略。
- [版本與 sync history 不完全等價] 使用者可能只產 HTML 但未重新同步 Apidog → 文件需明確說明版本資料夾代表 HTML 生成快照，不取代 `apidog-sync-history.jsonl`。
- [非正式輸出沒有版本備份] cherry-pick 或 `/tmp` 輸出不會進入正式 versions → 這符合現有 cherry-pick 不污染 `docs/api-docs/` 的設計。
