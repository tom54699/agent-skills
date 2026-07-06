## Why

一次針對「skill 自身更新後、已安裝專案如何同步」的全面盤點（涵蓋 `development-workflow`、`ai-project-index`、`laravel-api-docs`、`business-logic-workflow` 四個 skill）發現：`development-workflow` 的問題已由另一個 change（`sync-development-workflow-existing-projects`）處理，但其餘三個 skill 各自也有版本識別缺口，且比 `development-workflow` 更嚴重：

- `ai-project-index` 的四支 script 都寫死 `"version": "1.0.0"` 在輸出 JSON 裡，但**全 repo 沒有任何地方讀取或比對這個欄位**——是一個看起來像有機制、實際上完全沒用的裝飾性欄位。若未來 script 改了 `index.json`/`audit.json` 的 schema，舊專案殘留的舊格式檔案會被新版 script 悄悄誤讀，`audit-index.py` 也不會標記為 warning。
- `laravel-api-docs` 的 `apidog-sync-history.jsonl` 只有單一欄位級的 fallback（`path_strategy` 缺失時的處理），沒有系統化的 schema version，未來新增/改名其他欄位時得逐一補寫類似邏輯。
- `business-logic-workflow` 的輸出（Business Logic Brief / As-Is Summary / Delta）完全沒有版本概念，只有 `Status: draft/reviewed/...` 這種語意標記，無法判斷一份既有文件是哪個版本的 SKILL.md 產生的。

這次先建立最小可用的版本識別基礎，並讓 `ai-project-index` 的版本欄位從裝飾性變成真正有比對邏輯，其餘兩個 skill 先建立標記、暫不需要比對邏輯（風險較低：純文字/單一 jsonl 欄位，不像 JSON schema 那樣容易被靜默誤讀）。

## What Changes

- 三個 skill 的 `SKILL.md` frontmatter 都新增 `metadata.version`
- `skills/ai-project-index/scripts/audit-index.py`：讀取 `index.json` 的 `version` 欄位，若與腳本自身的期望版本不符，走既有的 `warning_audit()` 路徑（新增一個 `version_mismatch` reason），而不是靜默繼續產生 `status: "ok"` 的稽核結果
- `skills/laravel-api-docs/SKILL.md` 的同步歷史紀錄規格新增 `schema_version` 欄位，並把現有「`path_strategy` 缺失時 fallback」的規則，概念上歸納進「schema_version 未標記或較舊時，缺少的欄位一律回退偵測或舊預設」這個一般化規則
- `skills/business-logic-workflow/SKILL.md` 的三個 Output Shape（Brief/As-Is/Delta）都在 `Status:` 後新增一行 `Generated-by: business-logic-workflow vX.X.X`，讓文件本身標記是哪個版本產生的

無 **BREAKING** 變更：純新增欄位／新增標記行／新增比對分支，既有欄位與既有輸出格式維持不變，舊資料缺少新欄位時所有既有 fallback 規則繼續適用。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `ai-project-index-skill`：新增版本比對相關情境
- `business-logic-workflow-skill`：輸出格式新增版本標記相關情境
- `laravel-api-docs-sync-history-commit-baseline`：同步歷史紀錄新增 `schema_version` 欄位與對應的舊資料容錯情境

## Impact

- 受影響檔案：`skills/ai-project-index/SKILL.md`、`skills/ai-project-index/scripts/audit-index.py`、`skills/laravel-api-docs/SKILL.md`、`skills/business-logic-workflow/SKILL.md`
- 不影響：`development-workflow`（由另一個 change 處理）、任何模板檔案
- 不引入新的外部依賴
