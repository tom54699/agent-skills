## 1. Route index 根本修正

- [x] 1.1 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php::buildRouteIndex()`：對每條 route 過濾 `HEAD`/`OPTIONS` 後的每個 method 各自產生一筆 `RouteDefinition`
- [x] 1.2 `skills/laravel-api-docs/src/InferCandidates/Analyzer.php::buildRouteIndex()`：同樣改成每個 method 各自產生一筆 `RouteEntry`

## 2. Missing route 安全網警告

- [x] 2.1 `skills/laravel-api-docs/src/InferCandidates/EventEmitter.php` 新增 `warning()`，不受 `enabled`/`debug` 開關影響
- [x] 2.2 `OpenApiGenerator::normalizeCandidates()` 在 `$missing` 非空時，組出排序過的 `METHOD path` 清單並呼叫 `warning()`
- [x] 2.3 `skills/laravel-api-docs/scripts/gen-openapi.sh` 的 `php_event_adapter` 新增 `warning` 分支，印成 `⚠️  <message>` 到 stderr

## 3. 文件同步

- [x] 3.1 `SKILL.md` Step 4 route snapshot 說明補上多 method route 必須各自展開的規則
- [x] 3.2 `SKILL.md` Step 6 新增一項，記錄 missing route 必須顯眼警告，並重新編號後續項目

## 4. 驗證

- [x] 4.1 `php -l` 對三個修改的 PHP 檔案做語法檢查
- [x] 4.2 `bash -n` 對 `gen-openapi.sh` 做語法檢查
- [x] 4.3 手動整合測試：以假 `artisan` fixture（一條單 method route + 一條 `GET|POST|HEAD` route）跑 `bin/gen-openapi.php` full mode，確認 `/multi` 路徑同時產生 `get:` 與 `post:` operation（實測通過）
- [x] 4.4 手動整合測試：用 confirmed candidate 檔（一筆真實存在的 `POST /multi`、一筆不存在的 `DELETE /multi`）跑 `bin/gen-openapi.php --candidate-file`，確認 `POST /multi` 成功比對、只有 `DELETE /multi` 出現在 `missing_route_count=1` 與 warning 訊息（實測通過）
- [x] 4.5 透過 `gen-openapi.sh` 執行同一組 confirmed candidate 檔，確認 stderr 出現獨立的 `⚠️  ...` 警告行（實測通過）
- [x] 4.6 用 Reflection 直接呼叫 `Analyzer::buildRouteIndex()`（同一組 fixture），確認 `routeKeys()` 同時包含 `get /multi` 與 `post /multi`（實測通過）
- [x] 4.7 `openspec validate fix-multi-method-route-indexing --strict`
