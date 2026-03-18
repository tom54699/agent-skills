## Context

`laravel-api-docs` 的候選推測與 OpenAPI 更新主路徑已分別收斂到 PHP analyzer 與 PHP generator，但 guided-sync 的前後段仍有兩種落差：

1. Step 1 preflight 尚未驗證 PHP 執行條件，導致流程可能在候選推測或 OpenAPI 更新時才因 `php -n`、`artisan route:list --json` 失敗而中止。
2. Step 7 與 Step 9 的使用者契約已寫入 `SKILL.md`，但 `upload-apidog.sh` 與 `gen-html.sh` 尚未完整落地，尤其是 updated conflict detection 與 `extra.md` 額外內容。

同時，歷史過渡期留下的 shell parser / route scanner 已退出主路徑，若不整理，會繼續誤導維護者以為存在雙路徑 runtime。

## Goals / Non-Goals

**Goals:**
- 在 preflight 就攔下 PHP runtime 不符合 guided-sync 主路徑需求的專案環境。
- 讓 Apidog 同步步驟能對 `updated` 項目產出衝突清單，並遵守 `keep_remote / use_local / manual_merge` 契約。
- 讓 Redoc HTML 生成能依使用者選擇套用 `docs/api-docs/redoc/extra.md`。
- 明確清理已退出主路徑的過渡 shell 腳本與相關文件描述。

**Non-Goals:**
- 不重寫 Apidog 遠端比對成完整雙向同步引擎。
- 不變更 `infer-candidates` 或 `gen-openapi` 的主分析/生成邏輯。
- 不擴充 HTML 為多模板或自訂前端框架。

## Decisions

### 1. Preflight 必須檢查 runtime readiness，而不只檢查工具存在

`preflight.sh` 除了 `jq` / `yq` 外，還必須驗證：
- `php` 指令存在
- `php -n -r 'echo 1;'` 可執行
- `php -n artisan route:list --json` 可成功完成並產出可解析 JSON

理由：
- 現在 guided-sync 核心依賴的是 `php -n` 路徑，不是一般 `php`
- 只檢查 `php` 是否存在，無法保證 Laravel 專案在實際 runtime 下可用

替代方案：
- 只檢查 `php` binary 存在
  - 放棄，因為太弱，無法提前攔下專案級問題

### 2. Apidog 衝突處理採「本地與遠端 operation 比對 + 衝突檔案落地」

對 confirmed `updated` 項目，先從本地 `openapi.yaml` 取 operation，再查詢 Apidog 既有 operation，至少比對：
- `summary`
- `description`
- `parameters`
- `requestBody`
- `responses`
- `tags`

若有差異，輸出到 `docs/api-docs/conflicts/<timestamp>.json`，每筆帶：
- `method`
- `path`
- `conflict_type`
- `reason`
- `suggested_action`

策略：
- 未明確指定時預設 `keep_remote`
- `use_local` 才允許以本地覆蓋
- `manual_merge` 則中止自動上傳，保留衝突檔案供人工處理

替代方案：
- 完全不比對，直接依 Apidog import API 結果記錄 `conflict_count`
  - 放棄，因為這無法滿足 `SKILL.md` 既有契約

### 3. HTML 額外內容採可選注入，不回寫 OpenAPI

`gen-html.sh` 增加可選參數或預設探測 `docs/api-docs/redoc/extra.md`，將其轉成 HTML 區塊並插入 Redoc 頁面固定區域。

理由：
- `SKILL.md` 已明定 `extra.md` 只影響 HTML，不修改 OpenAPI
- 以 HTML 注入處理最簡單，不需改 OpenAPI schema 或 vendor extension

替代方案：
- 將 `extra.md` 內容塞回 OpenAPI description/vendor extension
  - 放棄，因為會污染同步到 Apidog 的唯一來源

### 4. 過渡 shell 腳本採明確移除，而非長期保留

`parse-controller.sh`、`parse-form-request.sh`、`parse-service.sh`、`scan-routes.sh` 已非主路徑必要元件。此 change 會先確認 repo 內無 runtime 依賴，再移除腳本與相關文件提及。

理由：
- 降低誤用與維護成本
- 避免新維護者誤以為仍有 shell / PHP 雙主路徑

替代方案：
- 繼續保留作為備援工具
  - 放棄，因為目前沒有正式 fallback 契約

## Risks / Trade-offs

- [Apidog 遠端資料模型與本地 OpenAPI 不完全同構] → 先將衝突判斷限制在 `SKILL.md` 明定欄位，其他欄位不納入阻塞條件。
- [preflight 增加 `php -n artisan route:list --json` 檢查會讓 Step 1 稍慢] → 接受這個成本，以換取後續主流程不在中段失敗。
- [刪除過渡腳本可能影響少數手動使用者] → 先同步更新 `SKILL.md` 與 change 文件，並確認 repo 內無 runtime 引用。
- [HTML 額外內容渲染方式過於簡單] → 先支援 Markdown 轉 HTML 的基本需求，不擴充成複雜模板系統。

## Migration Plan

1. 先擴充 `preflight.sh` 與 `SKILL.md`，確立 PHP runtime readiness 契約。
2. 再補 `upload-apidog.sh` 的衝突偵測、衝突檔案輸出與策略控制。
3. 補 `gen-html.sh` 的 `extra.md` 載入。
4. 最後移除過渡 shell 腳本與相關文件殘留。

回滾方式：
- 若 Apidog conflict handling 導致流程不穩，可暫時退回只產 conflict file、不阻擋上傳的保守模式。
- 若 HTML 額外內容渲染有問題，可先停用 `extra.md` 插入，不影響主 OpenAPI 文件。

## Open Questions

- Apidog 是否有足夠 API 可查詢單一路徑/operation 的既有定義，還是需要先取整份專案 schema 再本地比對。
- `manual_merge` 是否應直接阻擋同步，或允許產 conflict file 後由 LLM 與使用者確認再繼續。
