## Why

目前 `laravel-api-docs` 在無歷史紀錄的初始化階段容易產生過多候選項目，與日常實際需求（只處理新增 API）不一致。需要明確的初始化分流與基準建立流程，讓第一次使用可控且可追溯。

## What Changes

- 新增初始化分流流程：先確認基準來源（本地 OpenAPI / Apidog 匯出 / 無基準）。
- 無成功歷史時，要求使用者提供 `from_commit` 到目前時間作為初始化範圍。
- 初始化模式預設只推測 `new`，不做 `updated` 推測。
- 補強 baseline 建立規則，首次成功同步後寫入 history。
- 新增 fast/enhanced 分析層級：預設 fast，降低初始化 token 成本。

## Capabilities

### New Capabilities
- `laravel-api-docs-bootstrap-initialization`: 定義首次初始化分流、基準建立與初始化推測邏輯。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/SKILL.md`
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/laravel-api-docs/scripts/upload-apidog.sh`（初始化成功後 baseline 一致化）
- 影響流程：
  - 首次執行需先確認基準來源或指定 `from_commit`
  - 初始化不再輸出大量 `updated` 候選
