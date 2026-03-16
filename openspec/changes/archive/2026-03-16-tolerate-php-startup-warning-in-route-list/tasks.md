## 1. Route List 容錯

- [x] 1.1 在 route list 主鏈路清理 `php artisan route:list --json` 的前導非 JSON 輸出。
- [x] 1.2 在候選推測與 OpenAPI 生成主鏈路清理 `php artisan route:list --json` 的前導非 JSON 輸出。

## 2. 驗證

- [x] 2.1 驗證目前 wrapper / PHP 主鏈路已能接受前導 warning 後再解析 JSON。
- [x] 2.2 確認容錯已落在現行 PHP analyzer / generator 主路徑，而非已移除的舊 shell scanner。
