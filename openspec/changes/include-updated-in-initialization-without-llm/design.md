## Context

目前 `laravel-api-docs` 在初始化且無 OpenAPI baseline 時預設只推測 `new`，這在實務上會漏掉「既有 endpoint 但參數/回應已修改」的同步需求。此專案現階段以 shell 規則解析為主，不依賴 LLM，因此應透過更完整的關聯規則補齊 `updated` 推測能力。

限制條件：
- 維持無 LLM 路徑可執行與可重現。
- 初始化階段仍須由使用者提供 `from_commit`，確保範圍可控。
- `deleted` 在初始化不自動推測，避免誤刪歷史 API 文件。

## Goals / Non-Goals

**Goals:**
- 初始化（無 success history）時，候選輸出必須包含 `new` 與 `updated`。
- 即使只改 `FormRequest/Service/Exception/Resource`，也能回推出受影響 endpoint。
- 回應推測支援專案慣例 `response()->apiResponse(...)` 與 `BaseException` getter。
- 在候選輸出提供 `change_reason`、`confidence`、`missing_fields` 供人工審核。

**Non-Goals:**
- 本次不導入 LLM 補強流程。
- 本次不做 AST 大改（先維持 shell + 現有解析腳本）。
- 本次不自動處理初始化 `deleted` 候選。

## Decisions

1. 初始化模式由 `new-only` 改為 `new+updated`。
- 原因：前端需要的是「變更後文件」，非「只新增 API」。
- 替代方案：保留 `new-only` 並依人工補 `updated`。缺點是漏改風險高，且依賴人工記憶。

2. 採「正向 + 反向」雙軌關聯。
- 正向：`Controller@action` diff 命中對應 endpoint。
- 反向：`FormRequest/Service/Exception/Resource` 變更回推 `Controller@action` 再回推 endpoint。
- 替代方案：僅依 controller 變更。缺點是只改 rule/exception 會漏抓。

3. 回應推測採專案慣例優先。
- success：`response()->apiResponse(code, message, data, status)`。
- error：`catch (BaseException)` 取 `getErrorCode/getMessage/getData/getStatusCode`。
- fallback：`catch (Throwable)` 映射 500。
- 替代方案：通用 JSON 回應模板。缺點是與現行 API 實際格式偏差大。

4. 初始化階段仍不自動推測 `deleted`。
- 原因：首次導入易出現歷史文件不全，`deleted` 誤判代價高。
- 替代方案：初始化也推 `deleted`。缺點是需大量人工排除噪音。

## Risks / Trade-offs

- [風險] shell/regex 對特殊語法（多行鏈式呼叫、trait 動態注入）解析不穩。
  -> Mitigation：對無法確定的欄位輸出 `missing_fields` 與 `low confidence`，由使用者確認。
- [風險] 反向關聯增加計算成本。
  -> Mitigation：僅針對 `from_commit..HEAD` 的變更檔建立索引，不做全專案掃描。
- [風險] 專案慣例演進（例如 response helper 參數順序變更）導致誤判。
  -> Mitigation：在 SKILL.md 固定慣例假設與可覆寫點，並在輸出附上來源訊號。

## Migration Plan

1. 更新 `SKILL.md`：初始化模式改為 `new+updated`，補充反向關聯規則。
2. 修改 `infer-candidates.sh`：移除 `init_new_only` 硬限制，新增反向關聯推測路徑。
3. 擴充解析腳本：補強 `apiResponse` 與 `BaseException` 相關 response 訊號抽取。
4. 在測試 Laravel 專案執行初始化 dry-run，人工核對候選清單與 openapi 變更。
5. 若噪音仍高，新增更嚴格過濾旗標（例如只看 high confidence）。

Rollback：
- 回退腳本變更並恢復 `new-only` 行為。
- 保留本次產生的候選檔供事後比對，不覆蓋既有 history。

## Open Questions

- 是否需要在初始化提供開關（例如 `--init-include-updated=true|false`），或直接固定為 `true`？
- `ApiErrorCode` enum 是否要在本次直接映射到 OpenAPI examples，或先僅做 response schema 與 status 推測？
