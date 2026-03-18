## Why

目前 `laravel-api-docs` 在初始化模式下，會直接將使用者提供的 `--from-commit` 套用為 `<from_commit>..HEAD`。這符合原生 Git range 語意，但會排除該 commit 本身。對 guided-sync 的初始化使用情境來說，使用者說「從某個 commit 開始」時，通常期待的是包含那顆 commit 自己的 API 變更。

這個語意落差會直接造成初始化候選清單漏抓。像 `myan-ride` 這類實際專案中，使用者指定的 commit 本身已經包含 controller、request 與 route 相關修改，但工具卻只分析其後續提交，最後得到 `candidate_count = 0`，使初始化結果失真。

## What Changes

- 將初始化模式下的 `--from-commit` 語意改為「包含該 commit 本身」。
- 內部 range selection 改為使用該 commit 的 parent 作為 diff lower bound，讓 `changed_files` 與候選推測納入指定 commit 的內容。
- 補強 meta/debug 輸出，區分使用者輸入的 `from_commit` 與實際展開後的 `diff_range`。
- 對沒有 parent 的 root commit 提供明確錯誤訊息，而不是靜默排除或做隱性 fallback。
- 同步更新技能文件與 guided-sync 文件，明確說明初始化 `from-commit` 的產品語意。

## Capabilities

### Modified Capabilities
- `laravel-api-docs-bootstrap-initialization`: 初始化模式的 `from-commit` 必須包含指定 commit 本身，而非直接沿用 Git 排除式 range。
- `laravel-api-docs-range-selection`: range selection 必須對外揭露使用者輸入的 commit 與實際展開後的 diff range，並在無 parent 時明確報錯。

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/src/InferCandidates/RangeSelection.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/Analyzer.php`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - `docs/laravel-api-docs-guided-sync.md`
  - `tests/laravel_api_docs_commit_driven_test.php`
- 影響資料契約：
  - `docs/api-docs/candidates/<timestamp>.json` 的 `meta.diff_range`
  - 初始化模式的 debug / meta 觀測欄位
- 影響流程：
  - guided-sync 初始化時的 commit 範圍選擇
  - 初始化候選清單與使用者對「從某個 commit 開始」的預期一致性
