## Why

目前 `infer-candidates.sh` 在推測流程中若遇到無法解析的 controller/request/resource/exception/service 對應檔案，會因 `set -euo pipefail` 直接中止，導致結果尚未組完就退出。使用者即使提供 `--output`，也可能看不到輸出檔，增加排查成本。

## What Changes

- 修正 `infer-candidates.sh` 的 resolver miss 行為，找不到對應檔案時視為「無命中」而非整支腳本失敗。
- 確保腳本在可容忍的解析 miss 下仍能完成候選組裝並執行 `--output` 寫檔。
- 保持既有候選推測規則不變，不調整 `new/updated/deleted` 判定邏輯。

## Capabilities

### New Capabilities
- `laravel-api-docs-candidate-output-reliability`: 定義候選推測在解析 miss 時仍須完成輸出，避免 `--output` 落空。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
- 影響流程：
  - 候選推測在遇到未解析 symbol 時不中止。
  - `--output` 在推測完成後可穩定寫入結果檔。
