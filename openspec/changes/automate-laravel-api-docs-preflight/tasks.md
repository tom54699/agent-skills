## 1. Preflight 腳本

- [x] 1.1 新增 `skills/laravel-api-docs/scripts/preflight.sh`。
- [x] 1.2 檢查 Laravel 專案根目錄必要條件：`artisan`、`routes/`。
- [x] 1.3 檢查 `.env.agents` 是否存在且包含 `APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`。
- [x] 1.4 檢查 `.gitignore` 是否包含 `.env.agents`。
- [x] 1.5 建立 `docs/api-docs` 及其子目錄。
- [x] 1.6 檢查 `jq` / `yq` 等必要工具並輸出結構化結果。

## 2. 文件同步

- [x] 2.1 更新 `skills/laravel-api-docs/SKILL.md`，要求 guided-sync 先成功執行 `preflight.sh`。
- [x] 2.2 補充 preflight 成功 / 失敗時的後續處理規則。

## 3. 驗證

- [x] 3.1 執行 shell 語法檢查。
- [x] 3.2 驗證缺少 `.env.agents`、缺少 token/project id、缺少 `.gitignore` 設定時會中止。
- [x] 3.3 驗證成功時會建立必要目錄並輸出 JSON。
