# 專案協作原則

1. 全程使用繁體中文交流，除非使用者或專案文件明確要求其他語言。
2. 以後端工程與可維護性視角討論需求、資料、API、流程與測試。
3. 避免過度設計，優先滿足當前需求與清楚可驗證的行為。
4. 實作前先釐清需求、影響範圍、風險與驗收方式。
5. 涉及功能、API、設定、資料意義、流程、權限或文件契約的變更，須依專案指定流程（如 OpenSpec）建立並維護變更紀錄。
6. 文件集中於 `docs/`（或專案既有文件目錄）管理；功能、API、設定或流程變更後，須同步更新相關文件與測試。

---

## Behavioral Guidelines

以下規則節錄自 [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)，維持英文原文以降低翻譯失真：

### Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

> 此原則適用於單一任務執行過程中的「順手」修改；若使用者明確發起重構/改寫需求，仍依專案「重構 / 改寫 / 遷移」工作流程（Delta → OpenSpec）進行，不受此限制。

---

## Workflow 入口

### 初始化

使用以下指令初始化或重整本專案的 AI 協作規則：

```text
development-workflow init
```

初始化時，AI 必須先提出計畫，列出會建立或更新的檔案、建議安裝的 skills、專案假設與待確認規則；經使用者確認後才修改檔案。

### 新需求

收到需求單、功能想法、產品規則或玩法需求時：

1. 先使用 `business-logic-workflow` 整理 scoped Business Logic Brief。
2. 有阻擋問題時，先向使用者確認。
3. 需求要進入實作時，依專案規則建立 OpenSpec change。
4. 實作後同步更新 tests、docs 與相關 specs。
5. 若有 `.ai-project-index`，完成後重新整理索引。

### 舊邏輯理解 / 重構

要理解沒碰過的功能、重構、搬移、改寫或調整既有行為時：

1. 可先用 `.ai-project-index` 找候選檔案。
2. 使用 `business-logic-workflow` 的 Legacy As-Is 或 Delta 流程。
3. 業務行為必須以 source、tests、docs、accepted specs、configs 或使用者確認作為證據。
4. 未確認內容不得寫成已確認事實。
5. 影響行為、API、資料意義或流程時，須進入 OpenSpec 流程。

### 純技術小修

純技術小修是指不改變使用者可見行為、業務規則、資料意義、API contract、權限、付款、通知、狀態轉移或外部整合的調整。

這類工作可以略過完整 Business Logic Brief，但仍須遵守專案的 OpenSpec、測試與文件規則。若過程中發現會影響行為或 contract，必須改走新需求或舊邏輯 Delta 流程。

---

## Skills 使用順序

| 情境 | 優先使用 |
|------|----------|
| 新專案初始化 | `development-workflow init` |
| 新需求 / 需求單 | `business-logic-workflow` → OpenSpec |
| 舊功能理解 | `.ai-project-index` → `business-logic-workflow` |
| 重構 / 改寫 / 遷移 | `.ai-project-index` → `business-logic-workflow` Delta → OpenSpec |
| 純技術小修 | 確認行為中立 → 專案要求的 OpenSpec/tests/docs |
| 大量變更後 | refresh `.ai-project-index` |

---

## 文件與索引同步

- 文件集中於 `docs/` 或專案既有文件目錄。
- 長期業務邏輯文件只有在使用者明確要求保存時才建立或更新。
- `.ai-project-index` 只作為 AI routing aid，不是 source of truth。
- 變更 source、tests、docs、OpenSpec、project guidance 或 skill files 後，若專案有 `.ai-project-index`，應重新整理索引。

---

## OpenSpec 原則

若本專案使用 OpenSpec：

1. 新需求、行為變更、API/設定/流程變更先建立 proposal。
2. 實作依 tasks 進行並同步更新狀態。
3. 完成後執行 validation。
4. 驗證通過後再 archive change。
