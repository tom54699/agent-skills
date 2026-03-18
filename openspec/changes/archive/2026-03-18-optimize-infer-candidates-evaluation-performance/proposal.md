## Why

`infer-candidates.sh` 在初始化範圍較大時，主要時間幾乎都耗在 `candidate_evaluation`。目前已確認 `new / updated / deleted` 判定語意符合預期，因此這次需要的是純效能優化，而不是邏輯改版；主方案必須直接縮小 evaluation 工作集，而不是只靠微幅 cache。

## What Changes

- 將 `infer-candidates.sh` 改為先收斂 `candidate_route_subset`，再進行深度 evaluation。
- 把 prefilter 往主迴圈前推，避免對整份 route snapshot 做完整 evaluation。
- 預先建立低成本 lookup / hint 結果，減少 per-route 的 shell/jq/grep 次數。
- 將 `parse-controller.sh` 改為單次解析流程，降低 controller parse 在 subset build 中的成本。
- cache 只作為輔助，不作為主要優化手段。
- 保持現有候選輸出格式、debug/timing 格式與 guided-sync 主流程不變。

## Capabilities

### New Capabilities
- `laravel-api-docs-candidate-evaluation-performance`: candidate evaluation 必須先收斂 impacted route subset，再對 subset 做深度分析。

### Modified Capabilities
- `laravel-api-docs-candidate-inference-precision`: 不改候選判定語意，但允許調整實作以降低耗時。

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/.curated/laravel-api-docs/scripts/parse-controller.sh`
  - `skills/.curated/laravel-api-docs/SKILL.md`
- 影響行為：
  - 候選與 debug 結果應維持一致
  - `candidate_evaluation` 的 route 工作集應顯著小於 route snapshot
  - `candidate_subset` 中的 controller parse 耗時應下降
  - `candidate_evaluation` 與 `infer_total` 耗時應下降
