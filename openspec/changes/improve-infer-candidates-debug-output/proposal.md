## Why

`infer-candidates.sh --debug` 目前雖然有輸出足夠資訊，但欄位命名混合了「全集統計」、「baseline 差集」與「實際候選訊號」，在初始化且無 OpenAPI baseline 時特別容易誤讀。例如 `route diff: new_keys=445` 只是 route 與空 baseline 的集合差，卻容易被理解成真的推測出 445 個新 API。

## What Changes

- 重新命名並分組 `infer-candidates.sh` 的 debug 訊息。
- 在無 OpenAPI baseline 時，將 route/doc 差集標示為資訊性輸出，而非候選訊號。
- 同步更新 `skills/laravel-api-docs/SKILL.md` 的 debug 閱讀說明。

## Capabilities

### New Capabilities
- `laravel-api-docs-candidate-debug-clarity`: 定義候選推測 debug 輸出需區分 baseline 資訊、變更盤點與候選訊號，降低誤讀。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/laravel-api-docs/SKILL.md`
- 影響流程：
  - 僅改善 debug 可讀性，不改變候選推測結果。
