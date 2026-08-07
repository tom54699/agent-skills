## ADDED Requirements

### Requirement: Route index MUST expand every HTTP method a route responds to
當 `php artisan route:list --json` 回傳的單一 route 項目，其 `method` 欄位（以 `|` 分隔）在過濾掉 `HEAD`/`OPTIONS` 後仍剩下多個 method 時（例如 `Route::match(['get', 'post'], ...)` 或 `Route::any(...)`），候選推測（`InferCandidates/Analyzer.php`）與 OpenAPI 產生（`OpenApiGenerator.php`）用的 route index MUST 為每個 method 各自建立一筆獨立的 route 項目，共用同一份 controller/action/middleware 資料，不得只取第一個 method。

#### Scenario: Route registered with Route::match for multiple methods
- **WHEN** 一條 route 以 `Route::match(['get', 'post'], '/multi', ...)` 註冊
- **THEN** route index 必須同時包含 `get /multi` 與 `post /multi` 兩筆項目
- **AND** 候選推測階段必須能個別偵測到這兩個 method 的新增/刪除
- **AND** OpenAPI 產生階段對已確認的 `post /multi` 候選必須能比對到路由並產生對應的 `post:` operation

#### Scenario: Route with only one method is unaffected
- **WHEN** 一條 route 只註冊單一 method（例如 `Route::get('/single', ...)`）
- **THEN** route index 行為與修正前一致，只產生一筆該 method 的項目

### Requirement: Confirmed candidates that cannot be matched to any route MUST be surfaced as an explicit warning
`OpenApiGenerator::normalizeCandidates()` 在比對 confirmed 候選與 route index 後，若存在候選（`new`/`updated` 狀態）比對不到任何路由，MUST 把這些落單的 `method+path` 組成明確清單，透過獨立的 warning 事件輸出，且該輸出不得受 `--no-progress` 開關抑制；`gen-openapi.sh` 收到此事件時 MUST 印成獨立的一行，不得與其他 timing/debug 輸出混在一起或被靜默丟棄。

#### Scenario: A confirmed candidate has no matching route
- **WHEN** confirmed candidate 清單包含一筆 `method+path` 在目前 route index 中找不到對應項目
- **THEN** 系統必須明確列出該 `method+path`（而不是只累計數量）
- **AND** 該警告訊息必須以獨立事件輸出到 stderr，即使呼叫端帶了 `--no-progress`
- **AND** `gen-openapi.sh` 必須把該事件印成獨立、可辨識的一行警告

#### Scenario: All confirmed candidates match a route
- **WHEN** confirmed candidate 清單裡的每一筆都能在 route index 中找到對應項目
- **THEN** 不得輸出任何 missing-route 警告
