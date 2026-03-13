## Why

目前 `gen-openapi.sh` 雖然已接上 confirmed candidate 驅動流程，但核心解析仍仰賴 `parse-controller.sh`、`parse-service.sh`、`parse-form-request.sh` 三支 shell parser。這使得 OpenAPI 產生鏈路仍保留大量 subprocess、字串管線與重複解析，效能與穩定性都落後於已完成的 PHP 版 `infer-candidates`。

## What Changes

- 將 `gen-openapi.sh` 的 controller / service / form request 解析責任搬進單一 PHP 生成器，不再由 shell parser 當主要執行路徑。
- 保留既有 `gen-openapi.sh` 對外入口與 `--incremental` / `--candidate-file` 契約，但 shell 角色降為 wrapper。
- 讓 OpenAPI 產生與候選推測共用 PHP 解析能力，避免同一份 Laravel 原始碼被不同實作重複解析。
- 將 `parse-controller.sh`、`parse-service.sh`、`parse-form-request.sh` 自主路徑降級，並在後續收尾 change 完成後自 runtime 移除。

## Capabilities

### New Capabilities
- `laravel-api-docs-php-openapi-generator`: 以單一 PHP 程式完成候選 endpoint 的 OpenAPI 解析與文件輸出。

### Modified Capabilities
- `laravel-api-docs-guided-sync`: guided-sync 的 OpenAPI 更新階段改由 PHP 生成器提供，但確認清單與後續 Apidog / HTML 流程維持相容。

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/scripts/gen-openapi.sh`
  - `skills/laravel-api-docs/scripts/parse-controller.sh`
  - `skills/laravel-api-docs/scripts/parse-service.sh`
  - `skills/laravel-api-docs/scripts/parse-form-request.sh`
  - `skills/laravel-api-docs/SKILL.md`
  - 新增 `skills/laravel-api-docs/bin/` 或 `skills/laravel-api-docs/src/` 下的 PHP OpenAPI generator
- 影響行為：
  - `openapi.yaml` 結構與 `--candidate-file` / `--incremental` 契約應維持相容
  - `gen-openapi` 應顯著降低 subprocess 與重複 parser 呼叫
  - shell parser 不再是主路徑
