## Why

目前 `laravel-api-docs` 的候選推測同時混用「Git 變更範圍」與「本地 OpenAPI baseline 差集」。當專案的 `docs/api-docs/openapi.yaml` 覆蓋率很低時，日常執行會把大量未收錄但其實與本次提交無關的 routes 一次判成 `new`，使候選清單失真並失去日常同步價值。

## What Changes

- 將日常候選推測主軸改為 commit-driven：以最後一筆成功同步的 `git_head_commit..HEAD` 作為日常變更範圍，而非以 `synced_at` 時間窗為主基準。
- 將 candidate inference 改為只根據 commit 範圍內的 route/controller/request/service/resource/exception 變更訊號推導 impacted endpoints。
- 調整 baseline 的責任邊界：本地 `openapi.yaml` 不再直接決定候選 `new` 清單，只保留在 OpenAPI merge、刪除判定與診斷輸出使用。
- 補上 legacy history 相容策略：若舊 history 缺少可用 commit 基準，才退回時間窗推導 diff base，並在輸出中標示 fallback。
- 強化 debug / meta 輸出，清楚區分 commit-driven candidate signals、baseline coverage diagnostics 與 merge/delete diagnostics。
- 同步更新技能文件與 `docs/` 內流程文件，補上一份目前最完整的 guided-sync 執行說明與責任邊界。

## Capabilities

### New Capabilities
- `laravel-api-docs-commit-driven-candidate-inference`: 定義 guided-sync 以同步 commit 基準推導候選 API，並限制 baseline 僅作為文件 merge 與刪除判定的輔助資訊。
- `laravel-api-docs-sync-history-commit-baseline`: 定義同步歷史必須可提供日常推測所需的 commit 基準與 fallback 行為。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/src/InferCandidates/Analyzer.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/RangeSelection.php`
  - `skills/.curated/laravel-api-docs/scripts/append-sync-history.sh`
  - `skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - `docs/` 內 guided-sync 流程說明文件
- 影響資料契約：
  - `docs/api-docs/history/apidog-sync-history.jsonl`
  - `docs/api-docs/candidates/<timestamp>.json`
- 影響流程：
  - guided-sync 日常候選推測範圍
  - baseline/debug 訊息語意
  - 後續 OpenAPI merge 與 `deleted` 判定的責任邊界
