## Why

上一輪 `focus-candidate-inference-on-contract-surface` 已經把 candidate inference 從全量 dependency-driven 往 contract/doc-surface-driven 收斂，但實際在 `myan-ride` 驗證時仍出現偏寬的候選清單。像 `ff619fdd97103cc22752813b2ec902b56aa1cacf` 這種以 enum 取代字串為主的 refactor，雖然沒有明顯改動 request/response schema，仍因 controller method body diff 與 service exception metadata 而拉出 20 支 `updated` 候選。

這代表目前規則雖然已止血，但還沒收斂到「只有真正影響 API 文件契約或文件內容時才進候選」的程度。接下來需要再往前收一刀，明確區分強訊號與弱訊號，並把 function 文件註解變更列為正式的一級文件訊號。

## What Changes

- 將 candidate inference 訊號分成強訊號與弱訊號。
- 強訊號包含：
  - route / endpoint mapping 變更
  - request schema 變更
  - response schema / response metadata 變更
  - error contract / exception mapping 變更
  - function 文件註解變更，例如 description、`@queryParam`、`@bodyParam`、`@urlParam`、`@response` 等可映射到 OpenAPI 的註解
- 弱訊號包含：
  - controller method body diff
  - service method body diff
- 調整候選成立條件：
  - 強訊號可直接成立 `updated`
  - 弱訊號不得單獨成立 `updated`，必須搭配明確 contract/doc evidence
- 補強 `reason` / `signals`，讓使用者能區分這支候選是因註解、request、response、error contract，還是只是被內部 refactor 波及。

## Capabilities

### Modified Capabilities
- `laravel-api-docs-contract-surface-candidate-inference`: 進一步收斂 contract/doc-surface-driven 規則，導入強訊號 / 弱訊號判定與 function 文件註解作為一級訊號。

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/src/InferCandidates/Analyzer.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/ControllerParser.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/ActionMetadata.php`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - `docs/laravel-api-docs-guided-sync.md`
- 影響資料契約：
  - `docs/api-docs/candidates/<timestamp>.json` 的 `reason` / `signals` 會更明確區分強訊號與弱訊號
- 影響流程：
  - guided-sync 候選收斂更嚴格
  - `updated` 候選數量預期下降
  - 使用者確認清單時，應更接近真正需要更新文件的 API
