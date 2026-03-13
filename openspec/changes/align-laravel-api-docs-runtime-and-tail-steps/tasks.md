## 1. Preflight Runtime Readiness

- [x] 1.1 擴充 `skills/laravel-api-docs/scripts/preflight.sh`，檢查 `php` binary、`php -n` 可執行、以及 `php -n artisan route:list --json` 可成功產出有效 JSON。
- [x] 1.2 更新 `skills/laravel-api-docs/SKILL.md`，將 PHP runtime readiness 明確列入 Step 1 必要條件與錯誤訊息。
- [x] 1.3 驗證 preflight 在缺少 PHP、`php -n` 失敗、route:list 失敗時都會中止並輸出明確錯誤。

## 2. Apidog Conflict Alignment

- [x] 2.1 擴充 `skills/laravel-api-docs/scripts/upload-apidog.sh`，在上傳前針對 confirmed `updated` endpoint 執行本地/遠端 operation 比對。
- [x] 2.2 產出 `docs/api-docs/conflicts/<timestamp>.json`，並落地 `method`、`path`、`conflict_type`、`reason`、`suggested_action`。
- [x] 2.3 實作 `keep_remote`、`use_local`、`manual_merge` 三種策略，並讓未明確確認的衝突預設走 `keep_remote`。
- [x] 2.4 讓 history 的 `conflict_count` 來自實際 conflict result，而不是外部傳入的 placeholder 值。

## 3. Redoc Extra Content

- [x] 3.1 擴充 `skills/laravel-api-docs/scripts/gen-html.sh`，支援可選載入 `docs/api-docs/redoc/extra.md`。
- [x] 3.2 將 `extra.md` 內容渲染到 HTML 固定區塊，且不得修改 `docs/api-docs/openapi.yaml`。
- [x] 3.3 驗證未啟用 extra、啟用且存在、啟用但缺檔三種情境。

## 4. Cleanup And Documentation

- [x] 4.1 確認 `parse-controller.sh`、`parse-form-request.sh`、`parse-service.sh`、`scan-routes.sh` 已無 runtime 依賴。
- [x] 4.2 移除已退出主路徑的過渡 shell 腳本，並同步清理 `SKILL.md` 與相關 change 文件中的過時描述。
- [x] 4.3 執行語法與代表性流程驗證，確認 guided-sync 主鏈路、Apidog conflict handling、Redoc extra content 彼此不衝突。
