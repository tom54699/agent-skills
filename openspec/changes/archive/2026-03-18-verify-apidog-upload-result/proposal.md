## Why

目前 `upload-apidog.sh` 只看 import API 回傳的 counters 判定成功，但實測出現「API 回傳 imported/updated 非 0，後續 export 卻仍沒有任何 paths」的情況。這會讓 guided-sync 誤把失敗同步寫成 success history。

## What Changes

- 在 Step 7 增加 post-upload verification：上傳成功後必須重新 export 遠端 OpenAPI 驗證結果。
- 若 confirmed candidate 中的有效 endpoint 在遠端 export 仍缺席，這次同步必須視為失敗，不得寫 success history。
- 將 verification 結果輸出到結構化 JSON 與 timing，讓失敗原因可追查。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `laravel-api-docs-apidog-conflict-sync`: upload success must be validated by a post-upload remote export instead of relying solely on import counters.

## Impact

- 影響 `skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`
- 影響 Step 7 成功條件與 history 寫入時機
- 影響 `skills/.curated/laravel-api-docs/SKILL.md` 對 Apidog 同步成功定義的描述
