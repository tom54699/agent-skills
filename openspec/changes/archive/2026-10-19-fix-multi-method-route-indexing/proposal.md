## Why

使用者實跑 `laravel-api-docs` skill 時發現：對某個以 `Route::any()` / `Route::match([...])` 註冊、本身支援多個 HTTP method 的 route，確認過的候選（method+path）在 Step 6 產生 OpenAPI 時始終比對不到路由，一開始被誤判為候選格式問題，實際 root cause 在 route index 建置邏輯。

`OpenApiGenerator.php:165-167`（Step 6）與 `InferCandidates/Analyzer.php:271-273`（Step 4）兩處各自把 `route:list --json` 回傳的 `method` 欄位（用 `|` 分隔）過濾掉 `HEAD`/`OPTIONS` 後，只取剩餘清單的第一個當作該 route 的唯一 method。對只有單一 method 的 route 沒有影響，但對 `Route::any()`/`Route::match([...])` 這種一條 route 對應多個 method 的情況，其餘 method 會從 route index 完全消失：

- Step 4（`Analyzer.php`）：那些 method 連候選都不會被推測出來，使用者在確認清單裡根本看不到。
- Step 6（`OpenApiGenerator.php`）：即使候選清單手動標對了 method+path，也永遠比對不到 route，`buildOperation` 不會被呼叫，該 endpoint 靜靜地不會被寫進 OpenAPI。

而且這個失敗目前幾乎無聲：`normalizeCandidates()` 有計算 `missing_route_count`，但只塞進 `timingDetails` 的一行字串裡，跟其他 progress/timing log 混在一起，不會列出具體是哪個 method+path 沒對到。

## What Changes

- `OpenApiGenerator::buildRouteIndex()` 與 `Analyzer::buildRouteIndex()` 都改成對每條 route 的每個非 `HEAD`/`OPTIONS` method 各自產生一筆 `RouteDefinition`/`RouteEntry`（同一個 controller/action/middleware，method 不同），而不是只取第一個。
- `EventEmitter` 新增 `warning()`，不受 `--no-progress`/`--debug` 開關影響，總是輸出。
- `OpenApiGenerator::normalizeCandidates()` 在有候選比對不到路由時，透過 `warning()` 明確列出這些 method+path 清單，作為安全網；`gen-openapi.sh` 的 event adapter 對 `warning` 類型事件印成獨立、加上 `⚠️` 前綴的一行，而不是落入預設分支被當成任意 debug 輸出。
- `SKILL.md` Step 4 route snapshot 說明與 Step 6 新增一項，記錄「多 method route 必須各自展開」與「missing route 必須顯眼警告」兩條規則。

無 **BREAKING** 變更：純粹修正 route index 的資訊遺失問題與補上警告輸出，既有單一 method route 的行為、OpenAPI 既有欄位格式、候選 JSON 格式皆不變。

## Capabilities

### New Capabilities
- `laravel-api-docs-multi-method-route-indexing`：route index 建置必須完整涵蓋一條 route 註冊的每個 HTTP method，以及候選比對失敗時的顯眼警告規則。

### Modified Capabilities
（無，本次以新 capability 描述涵蓋此行為，不修改既有 capability spec）

## Impact

- 受影響檔案：
  - `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
  - `skills/laravel-api-docs/src/InferCandidates/Analyzer.php`
  - `skills/laravel-api-docs/src/InferCandidates/EventEmitter.php`
  - `skills/laravel-api-docs/scripts/gen-openapi.sh`
  - `skills/laravel-api-docs/SKILL.md`
- 不影響：Apidog 上傳流程（Step 7 以後）、既有 OpenAPI 檔案格式、confirmed candidate JSON schema
- 不引入新的外部依賴
