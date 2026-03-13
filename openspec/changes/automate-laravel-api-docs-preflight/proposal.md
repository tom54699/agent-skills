## Why

`laravel-api-docs` 的 Step 1 Preflight 目前主要靠文件約束與代理人工遵守，缺少可重複執行的自動檢查入口。這會讓流程容易因對話中的主觀判斷而偏離，例如跳過 `.env.agents`、漏建必要目錄，或在缺少依賴工具時仍繼續往下執行。

若要確保 guided-sync 流程不闕漏，Preflight 必須由 shell script 明確執行，並在缺少條件時立即阻止後續步驟。

## What Changes

- 新增 `preflight.sh` 作為 guided-sync 的統一前置檢查入口。
- 將 Laravel 根目錄、`.env.agents`、必要目錄、工具依賴等檢查條件落成可執行規則。
- 輸出結構化結果，讓後續腳本或 LLM orchestration 能一致判斷是否可繼續。

## Capabilities

### New Capabilities
- `laravel-api-docs-preflight-automation`: guided-sync 必須透過自動化 preflight 檢查來驗證執行前提。

### Modified Capabilities
- `laravel-api-docs-guided-sync`: Step 1 改為必須先成功執行 `preflight.sh` 才能進入候選推測。

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/SKILL.md`
  - 新增 `skills/laravel-api-docs/scripts/preflight.sh`
- 影響流程：
  - guided-sync 先跑 preflight，再進入 `infer-candidates.sh`
  - 缺少關鍵條件時，流程明確中止而非依代理自由判斷
