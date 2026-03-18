## Why

目前 `laravel-api-docs` 的 candidate inference 仍會把部分 service、dependency 與內部流程變更視為 API 文件更新訊號。這雖然有助於提高召回率，但也會把許多不影響 API 契約的內部修改放進候選清單，增加人工確認噪音，弱化 guided-sync 作為「文件同步」流程的精準度。

## What Changes

- 將 candidate inference 的判定主軸從廣義 dependency-driven 收斂為 contract-and-doc-surface-driven。
- 明確定義哪些變更屬於 API 文件表面：
  - route 與 endpoint mapping
  - request schema
  - response schema
  - error contract / exception mapping
  - controller 註解中的 description 與可映射到 OpenAPI 的參數說明
- 降權或忽略純內部實作變更，例如一般 service 內部流程、局部變數、repository/query 細節，只要它們沒有改變 API 契約或文件內容，就不應單獨產生 candidate。
- 保留 exception 對外錯誤契約變更的推導能力，避免因過度收斂而漏掉 status code、error payload 或錯誤訊息結構異動。
- 補上文件與測試，清楚說明 candidate inference 的責任邊界與可接受的噪音/漏抓取捨。

## Capabilities

### New Capabilities
- `laravel-api-docs-contract-surface-candidate-inference`: 定義 candidate inference 必須以 API contract 與文件表面變更為主，並限制純內部 dependency 變更不得單獨構成候選。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/src/InferCandidates/Analyzer.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/ControllerParser.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/ActionMetadata.php`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - `docs/laravel-api-docs-guided-sync.md`
- 影響資料契約：
  - `docs/api-docs/candidates/<timestamp>.json` 的 `reason` / `signals` 語意可能更偏向 contract surface
- 影響流程：
  - guided-sync 的候選收斂規則
  - 使用者對 `updated` 候選的人工確認預期
  - 後續測試案例需補上 annotation、exception contract 與 internal-only 變更的界線
