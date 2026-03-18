## Why

目前候選推測在 Service 檔案變更時，常以「檔案層級」直接擴大為所有相關 API，導致 `updated` 清單過大、審核成本高，且容易讓使用者忽略真正有影響的 endpoint。需要把推測粒度提升到 method/action 層級，讓候選範圍與實際變更更一致。

## What Changes

- 將 `updated` 推測由檔案層級改為函式層級：先從 `git diff` 抽出變更 method，再映射到 `Controller@action` 與 route endpoint。
- 新增 deterministic 關聯圖規則：`Service::method -> Controller@action -> METHOD PATH`，避免同 service 內未受影響 action 被誤標。
- 補強 Request/Resource/Exception 關聯判定，統一採「被 action 實際引用」才納入 `updated`。
- 追加候選來源訊號欄位，能清楚標示是「method 命中」還是「依賴關聯命中」，提升人工確認效率。
- 保留初始化/日常既有流程，不改變最終輸出檔案（`openapi.yaml`、Apidog 同步）與人工確認節點。

## Capabilities

### New Capabilities
- `laravel-api-docs-candidate-inference-precision`: 定義候選推測從檔案層級提升到 method/action 層級的規則，降低 `updated` 誤報與範圍膨脹。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/.curated/laravel-api-docs/scripts/parse-controller.sh`
  - `skills/.curated/laravel-api-docs/scripts/parse-service.sh`
  - `skills/.curated/laravel-api-docs/SKILL.md`
- 影響流程：
  - Step 2 候選推測將優先採 method/action 命中，降低噪音。
  - 使用者在候選確認階段會看到更精準的 `updated` 清單與理由。
