## Why

使用者反映：在其他專案實際使用 `laravel-api-docs` skill 時，只要話裡點名某個特定 API，經常要來回問好幾次，Claude 才會抓到使用者真正想要的模式。沒有單一可重現的對話範例，但根因可以從既有規格推出來：

- `cherry-pick-mode` 的觸發只認固定短語（「cherry-pick」、「挑幾個 API」、「只想上傳這幾個 API」等），而 cherry-pick 本身**只從既有 `openapi.yaml` 挑選重發**，不重新分析原始碼。
- 一句自然的「幫我處理/更新 OOO 這支 API 的文件」不會命中任何 cherry-pick 觸發詞，會直接落入 guided-sync 主流程——但 guided-sync 是以整段 commit diff 為範圍做候選推測，並不會因為使用者口頭點名了一支 API 就縮小分析範圍。
- 結果是：使用者點名一支 API，Claude 卻先跑了一輪跟整個 diff 範圍相關的候選推測，使用者要到看到結果才發現「不是我要的」，只好再說一次、甚至說第三次，才問到「你到底是要重新分析程式碼，還是只是要重發既有文件」這個真正的分岔點。

這個分岔點（程式碼有沒有變 → 決定該重新分析還是只重發既有 spec）目前完全沒有在 SKILL.md 裡出現，需要補上一條規則，讓 LLM 在動用任何腳本前就先問這一句，而不是先猜再讓使用者發現猜錯。

## What Changes

- `SKILL.md` 的 Cherry-pick 模式新增一節「點名特定 API 時的模式判斷」：當使用者點名一個或少數幾個具體 API，但沒有明確用到 cherry-pick 觸發詞時，LLM 必須先用一句話問清楚是「程式碼剛寫/改過，需要重新分析」還是「程式碼沒變，只是要重發既有文件」，再決定走 guided-sync 還是 cherry-pick。
- 不新增任何腳本邏輯或技術性範圍縮小機制；guided-sync 的候選範圍仍是整段 diff，Step 5 既有的「移除候選」機制維持不變，這條規則只解決「先問清楚意圖」的溝通順序問題。

無 **BREAKING** 變更：純粹新增一條互動規則，兩個既有模式（guided-sync、cherry-pick）本身的行為與既有觸發詞都不變。

## Capabilities

### Modified Capabilities
- `cherry-pick-mode`：新增「使用者點名特定 API 但未使用明確觸發詞時，LLM 必須先確認程式碼是否變更以判斷模式」的情境。

## Impact

- 受影響檔案：`skills/laravel-api-docs/SKILL.md`
- 不影響任何腳本、程式碼或既有 OpenAPI/candidate JSON 格式
