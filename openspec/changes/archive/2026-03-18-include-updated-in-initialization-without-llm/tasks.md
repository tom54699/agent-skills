## 1. 初始化流程與文件規格更新

- [x] 1.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`：初始化模式由 `new-only` 改為 `new+updated`。
- [x] 1.2 在 `SKILL.md` 補充初始化預設不推測 `deleted` 的規則與理由。
- [x] 1.3 在 `SKILL.md` 補充反向關聯來源（FormRequest/Service/Exception/Resource -> Controller@action -> endpoint）。

## 2. 候選推測腳本調整

- [x] 2.1 修改 `infer-candidates.sh`：移除初始化 `init_new_only` 對 `updated` 的排除邏輯。
- [x] 2.2 新增反向關聯推測：檔案變更命中 FormRequest/Service/Exception/Resource 時回推出 `updated` endpoint。
- [x] 2.3 調整輸出欄位：補上 `change_reason`、`missing_fields` 並保留 `confidence`。

## 3. 深度解析規則補強（無 LLM）

- [x] 3.1 擴充 controller 解析：抽取 `response()->apiResponse(code, message, data, status)` 的 success/fallback 訊號。
- [x] 3.2 擴充 exception 解析：支援 `BaseException` getter（`getErrorCode/getStatusCode/getData`）對應 response 推測。
- [x] 3.3 串接 FormRequest 規則解析結果到候選審核輸出，標記無法判定欄位為 `missing_fields`。

## 4. 驗證與回歸

- [x] 4.1 驗證初始化（無 baseline）時候選同時包含 `new` 與 `updated`。
- [x] 4.2 驗證只改 FormRequest 規則時，對應 endpoint 會被標記為 `updated`。
- [x] 4.3 驗證只改 Service/Exception 回應邏輯時，對應 endpoint 會被標記為 `updated`。
- [x] 4.4 驗證初始化預設不輸出 `deleted`，避免誤刪風險。
