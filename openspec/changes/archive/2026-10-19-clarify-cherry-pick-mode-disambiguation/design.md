## Context

`cherry-pick-mode` 現有的觸發規格（`openspec/specs/cherry-pick-mode/spec.md`）只處理兩個明確端點：使用者說出 cherry-pick 觸發詞 → 進 cherry-pick；使用者說「幫我產生 API 文件」這類泛用語 → 進 guided-sync。中間有一大段自然語言（點名一支具體 API，但沒有用到任一組固定短語）沒有規則覆蓋，落入預設值（guided-sync），但 guided-sync 的候選推測是整段 commit diff 範圍，跟使用者「只想處理這一支」的意圖不一定吻合。

## Goals / Non-Goals

**Goals**
- 找出使用者話裡「點名一支 API」與「該用哪個模式」之間真正的判斷依據：程式碼有沒有變。
- 讓 LLM 在跑任何腳本前就先問這一句，而不是跑完 guided-sync 一輪後才發現不對。

**Non-Goals**
- 不新增「只分析單一 API」的技術範圍縮小機制（guided-sync 內部仍是整段 diff 範圍 + Step 5 手動篩選）。
- 不修改 cherry-pick 既有的既定觸發詞清單，只補充「未命中固定短語時」的下一步規則。

## Decisions

### 判斷依據：程式碼是否變更，而不是用字精確度

與其嘗試窮舉更多自然語言觸發詞（永遠列不完），更穩定的做法是把問題交還給使用者能明確回答的事實：「這支 API 的程式碼是不是剛寫/改過？」

- 是 → guided-sync（可以口頭確認只針對這支，但技術上仍是整段 diff 推測 + Step 5 篩選）
- 否 → cherry-pick（從既有 `openapi.yaml` 挑出來重發）

### 只在「點名具體 API 但未命中觸發詞」時才問

若使用者已經明確說「cherry-pick」或「只想上傳這幾個 API」，不需要再問（原有觸發規則已足夠明確）。若使用者說「全部 API」、「所有變更」這類全面性字眼，也不需要問，直接視為 guided-sync 完整範圍。只有「點名了少數具體 API/endpoint，但字面上判斷不出模式」這個中間地帶需要新規則介入。

## Migration Plan

1. 在 `SKILL.md` 的 `## Cherry-pick 模式` 底下新增「點名特定 API 時的模式判斷」小節。
2. 不需要修改任何腳本或既有觸發詞清單。
