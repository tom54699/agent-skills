## Context

`php artisan route:list --json` 對用 `Route::match(['get', 'post'], ...)` 或 `Route::any(...)` 註冊的 route，會把 `method` 欄位回傳成用 `|` 分隔的字串，例如 `"GET|POST|HEAD"`。兩個 `buildRouteIndex()`（`OpenApiGenerator.php`、`InferCandidates/Analyzer.php`）都先過濾掉 `HEAD`/`OPTIONS`，再用 `$methodParts[0] ?? 'GET'` 只取第一個，导致同一條 route 只會產生一筆索引項目，其餘 method 從此在後續所有比對（候選推測、confirmed 比對、OpenAPI 產生）中都不存在。

這不是候選 JSON 格式錯誤，也不是使用者標錯 method——route index 本身在建置階段就已經遺失資訊，任何下游比對都無法補救。

## Decision

1. **Root fix**：`buildRouteIndex()` 對每條 route 的 `$methodParts`（過濾 `HEAD`/`OPTIONS` 後）逐一 foreach，每個 method 各自 new 一筆 `RouteDefinition`/`RouteEntry`，controller/action/middleware 共用同一份資料。`RouteIndex` 本身是純 `list<RouteDefinition>`（`OpenApiGenerator`）或以 `routeKey()` 為 key 的 map（`InferCandidates`），兩者都天然支援同一 path 有多筆不同 method 的項目，不需要額外改資料結構。
2. **Safety net**：`normalizeCandidates()` 已經算出 `missing`（confirmed 但比對不到 route 的 key），只是輸出管道錯了——原本塞進 `timingDetails` 字串。新增 `EventEmitter::warning()`，不受 `enabled`/`debug` 開關影響（跟 progress/timing 不同，這是需要使用者一定看到的資訊遺失警訊，不應該被 `--no-progress` 關掉），`gen-openapi.sh` 的 `php_event_adapter` 對 `warning` 類型印出 `⚠️  <message>` 到 stderr，不落入預設分支被當成任意除錯輸出忽略。

## Alternatives Considered

- 只修 `OpenApiGenerator.php`（使用者原始回報範圍）：會漏掉 `InferCandidates/Analyzer.php` 裡完全相同的 bug，該處是候選推測的第一道關卡，範圍更早也更根本——候選清單裡可能一開始就看不到那個 method，Step 6 的問題只是第二層失效。因此選擇兩處一起修。
- 讓 `RouteIndex`（OpenApiGenerator 版本）改成以 path 為 key、value 是 method 陣列的巢狀結構：會牽動 `RouteIndex`/`RouteDefinition` 的既有介面與所有呼叫端（`buildGeneratedDocument`、`normalizeCandidates`、review artifact 產生），改動面過大且非必要——目前的 `list<RouteDefinition>` + `routeKey()` 比對模式已經天然支援一路徑多筆記錄，只需在建置階段展開即可。

## Risks

- 展開後同一 path 會有多筆 `RouteDefinition`，若下游有任何程式碼假設「一個 path 只對應一筆 route」會出錯。已檢查 `buildGeneratedDocument`（寫入 `$document['paths'][$path][$method]`，本來就是 method-keyed，天然相容）與 `normalizeCandidates`（用 `routeKey()` = method+path 比對，天然相容），確認無此假設。
- `EventEmitter::warning()` 不受 `--no-progress` 影響，理論上會讓已經選擇關閉進度輸出的呼叫端多看到訊息；可接受，因為這是資訊遺失警訊，語意上不應該被進度開關靜音。
