## Context

今天新增的 Plugin Recommendations（四層分類：必裝／依訊號複選／條件式／排除）在 `add-development-workflow-plugin-recommendations`（已封存）裡只解決了「第一次跑 init」的情境。使用者接著測試「未來要更新這個 skill 給其他專案用」時，發現 init 對「這個專案是不是已經跑過 init」完全沒有記憶機制——每次都是從零推導，不會參考上一次的決策結果。

盤點（Explore agent）確認這是四個 skill 共通的問題，但規模不同：`development-workflow` 的核心症狀（重複推薦已裝的東西、不處理排除清單衝突）用一個輕量的「讀取上次決策記錄」機制就能解決；其他三個 skill 的版本化需求牽涉到腳本輸出格式（`ai-project-index` 的 JSON schema、`laravel-api-docs` 的 jsonl 格式、`business-logic-workflow` 的文件模板），適合另開一個 change 處理。

## Goals / Non-Goals

**Goals:**
- `init` 重跑時，能讀取專案既有 `AGENTS.md`/`CLAUDE.md` 裡記錄的 plugin 決策，避免重複推薦已安裝的項目
- 偵測到專案已安裝「明確排除清單」裡的 plugin 時，提醒衝突但不主動移除
- 建立最小可用的版本識別基礎（`metadata.version`），供未來擴充比對邏輯使用

**Non-Goals:**
- 不建立完整的 skill 版本相容性檢查系統（例如自動偵測「這個政策檔案是用哪個 SKILL.md 版本產生的、現在版本是否相容」）——這次只解決 plugin 推薦重複與排除衝突兩個具體症狀
- 不處理 `ai-project-index`／`laravel-api-docs`／`business-logic-workflow` 的版本化缺口——由獨立 change 處理
- 不自動安裝、移除、或修改任何 plugin 設定——衝突偵測只提醒，不採取行動

## Decisions

**1. 決策記錄寫進政策檔案本身，不另開新檔案**
`AGENTS.md`/`CLAUDE.md` 已經是 init 會讀寫的檔案，把 plugin 決策記錄成固定區塊（例如「## Plugin Decisions」）比另外維護一個 `.claude/development-workflow-state.json` 更符合「Keep the workflow pragmatic」的 Core Rule——不引入新的狀態檔案格式與讀寫邏輯。

*替代方案考慮過*：獨立 state 檔案（如 `.claude/development-workflow-state.json`）。捨棄理由：多一個需要維護相容性的檔案格式，這正是這次要避免的問題模式；寫進政策檔案本身，人也看得懂、不需要額外工具解析。

**2. 已安裝偵測讀取 `.claude/settings.json` 的 `enabledPlugins`，決策記錄讀取政策檔案，兩者互補**
`enabledPlugins` 是 Claude Code 官方的真實安裝狀態來源，比政策檔案裡的紀錄更權威（政策檔案可能沒更新、但 plugin 已經手動裝了）；政策檔案裡的決策記錄則補上「使用者當初為什麼婉拒某個推薦」這種 `enabledPlugins` 裡查不到的脈絡。兩者都讀取，`enabledPlugins` 為準。

**3. 排除清單衝突只提醒、不建議移除**
移除或停用一個使用者已經在用的 plugin 是有風險的操作（可能有自訂設定依賴它），init 不該擅自建議這麼做。只需要讓使用者知道「這個 plugin 跟本專案的 OpenSpec 慣例有已知衝突」，讓他自己判斷要不要處理。

## Risks / Trade-offs

- **[風險] 政策檔案裡的決策記錄區塊格式如果寫得不夠明確，未來 init 重讀時可能解析錯誤** → **緩解**：用固定的 Markdown 清單格式（plugin 名稱 + 狀態：installed/declined/excluded-detected），格式簡單到不需要嚴格 parser，人工也能讀懂並手動修正
- **[風險] `enabledPlugins` 若不存在（使用者用其他方式安裝 plugin，未落在這個設定檔），已安裝偵測會失準** → **緩解**：這只是「盡力偵測」，偵測不到就照舊推薦，不會因為誤判而漏掉真正需要的推薦；不是安全關鍵功能
- **[風險] `metadata.version` 目前沒有任何比對邏輯使用它，可能重蹈 `ai-project-index` 版本欄位「裝飾性」的覆轍** → **緩解**：明確定位這次只是「建立欄位」，不是「建立比對機制」；真正的版本比對邏輯留給未來需要時再設計，避免這次過度設計一套用不到的機制

## Migration Plan

無需資料遷移。既有專案第一次在此更新後重跑 `development-workflow init` 時，因為政策檔案裡還沒有「Plugin Decisions」區塊，行為等同於全新專案（不會出錯，只是這一次無法跳過已裝項目）；從這次 init 之後開始正常記錄與讀取。
