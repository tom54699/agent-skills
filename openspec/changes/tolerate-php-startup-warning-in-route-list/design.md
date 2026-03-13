## Context

這次在 `myan-ride` 專案實跑 guided-sync 時，`php artisan route:list --json` 的 stdout 開頭包含：

```text
Warning: PHP Startup: Unable to load dynamic library 'openswoole.so' ...
```

導致 `jq` 直接失敗。這類問題的本質不是 route parsing 規則錯誤，而是 JSON producer 的 stdout 被前導訊息污染。

## Decision

不針對特定 warning 字串硬編碼，而是採用「只保留第一個 JSON 開頭 (`[` 或 `{`) 之後的內容」的清理策略。

## Risks

- 若 stdout 在 JSON 前含有合法但不相關的 `{` / `[` 開頭資料，仍可能誤判。
  -> 目前 `route:list --json` 的實際污染型態是前導文字 warning，此風險可接受。
