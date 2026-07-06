## Why

今天新增的 Plugin Recommendations 邏輯暴露出 `development-workflow init` 的一個結構性問題：init 只檢查目標專案「現在長怎樣」（技術棧訊號、現有政策檔案），完全不讀取「這個專案上次跑 init 時，`development-workflow` 記錄過哪些決策」。這造成兩個具體症狀：已經安裝過的 plugin 會被重複推薦；如果專案已經安裝了本 repo 明確排除清單裡的 plugin（例如在採用這份規則之前就裝了 `feature-dev`），init 完全不會偵測到、也不會提醒有衝突。

盤點時也發現根本原因更深一層：四個 skill 都沒有任何自身版本識別機制，導致「已安裝的專案要怎麼判斷自己是哪個版本的行為產生的」這件事無從查起。這次先在 `development-workflow` 建立最小可用的版本識別基礎，解決眼前這兩個症狀；其餘三個 skill（`ai-project-index`、`laravel-api-docs`、`business-logic-workflow`）各自的版本化缺口規模更大，另開一個獨立 change 處理，避免這次範圍失控。

## What Changes

- `skills/development-workflow/SKILL.md` frontmatter 新增 `metadata.version`，作為版本識別的最小基礎
- `init` 產生 `AGENTS.md`/`CLAUDE.md` 時，記錄本次的 plugin 決策（已安裝/推薦但使用者婉拒/排除）到政策檔案裡的固定區塊
- `init` 的訊號偵測步驟新增：讀取目標專案 `.claude/settings.json` 的 `enabledPlugins`（或既有政策檔案裡記錄的決策區塊），判斷哪些候選 plugin 已經安裝，跳過重複推薦
- `init` 新增衝突偵測：若偵測到專案已安裝「明確排除清單」裡的 plugin，提醒衝突原因，但不主動建議移除
- `Init Output Shape`/`Init Output Result` 模板新增欄位呈現「已安裝、略過推薦」與「偵測到排除清單衝突」的狀態

不涉及 `assets/AGENTS.template.md`／`assets/CLAUDE.template.md` 本身的內容——這次只是讓 init 的**判斷邏輯**更聰明，不是新增要寫進模板的固定文字。

無 **BREAKING** 變更：純新增判斷步驟與呈現欄位，既有流程步驟不變。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `development-workflow-skill`：`Init Command` 與新增的 `Plugin Recommendations` requirement 需要新增「既有專案同步」相關情境

## Impact

- 受影響檔案：`skills/development-workflow/SKILL.md`
- 不影響：`assets/AGENTS.template.md`、`assets/CLAUDE.template.md`、其他三個 skill（其版本化缺口由另一個獨立 change 處理）
- 不引入新的外部依賴
