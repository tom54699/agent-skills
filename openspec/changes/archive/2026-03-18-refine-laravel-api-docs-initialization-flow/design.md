## Overview

本變更針對 `laravel-api-docs` 首次使用時的初始化體驗進行收斂，避免在無歷史基準時推測過多候選項目。核心做法是引入初始化分流與 commit 範圍控制，並把初始化推測預設為 `new-only`。

## Initialization Flow

1. 檢查成功 history
- 讀取 `docs/api-docs/history/apidog-sync-history.jsonl`。
- 若存在 `status=success`，走既有日常流程（時間範圍推測）。

2. 無 success history 時進入初始化分流
- 問使用者基準來源：
  - 本地 OpenAPI 檔案
  - 從 Apidog 匯出
  - 無基準（新專案或不回補舊 API）

3. 分流處理
- 本地 OpenAPI：放置到 `docs/api-docs/openapi.yaml` 並驗證。
- Apidog 匯出：匯出後存為 `docs/api-docs/openapi.yaml` 並驗證。
- 無基準：要求使用者提供 `from_commit`，作為初始化範圍。

4. 初始化候選推測
- 若無 OpenAPI 基準檔，僅輸出 `new`。
- 不推測 `updated`，避免噪音與誤判。

5. 首次同步成功後建立 baseline
- 上傳成功即 append history。
- 後續改用 `synced_at` 作日常推測基準。

## Cost Control

- `fast`（預設）：純腳本結構化抽取，不做 LLM 語意強化。
- `enhanced`：僅針對確認清單進行 LLM 補強。

## Script Changes

1. `infer-candidates.sh`
- 新增 `--from-commit` 參數（僅初始化時必填）。
- 新增初始化模式旗標（例如 `init_mode`），控制 `new-only`。

2. `upload-apidog.sh` / `append-sync-history.sh`
- 無論初始化或日常，成功後寫入一致格式的 history。

3. `SKILL.md`
- 補初始化問答分流與範圍規則。
- 明確說明初始化 `new-only` 與日常 `new/updated/deleted` 的差異。
