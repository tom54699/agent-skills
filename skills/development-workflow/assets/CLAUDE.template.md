# Claude Code 協作指引

## 基本原則

1. 全程使用繁體中文。
2. 以後端工程、資料流、API contract、測試與可維護性為主要討論視角。
3. 實作前先釐清需求、影響範圍、風險與驗收方式。
4. 避免過度設計，除非需求或風險需要更完整的設計。
5. 所有專案變更（需求、設計、任務與執行狀態）皆須依專案指定流程（如 OpenSpec）建立並維護紀錄。
6. 文件集中於 `docs/`（或專案既有文件目錄）管理；功能、API、設定、資料意義或流程變更都必須同步更新相關文件與測試。

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

## Development Workflow

本專案使用 `development-workflow` 作為 AI 開發流程入口。

### 初始化

使用：

```text
development-workflow init
```

執行時先產生初始化計畫，確認後才建立或更新 `AGENTS.md`、`CLAUDE.md`、文件規則、OpenSpec 規則與索引更新規則。

### 日常分流

| 情境 | 流程 |
|------|------|
| 新需求 / 需求單 | `business-logic-workflow` Business Logic Brief → OpenSpec → 實作 |
| 了解舊邏輯 | `.ai-project-index` 找路徑 → 讀 source/tests/docs/specs → `business-logic-workflow` As-Is |
| 重構 / 改寫 / 遷移 | As-Is → To-Be → Delta → OpenSpec → 實作 |
| 純技術小修 | 確認不改行為與 contract → 依專案規則測試與更新文件 |
| 大量變更後 | refresh `.ai-project-index` |

---

## Business Logic 規則

- 新需求先整理 Business Logic Brief。
- 舊邏輯必須用 source、tests、docs、accepted specs、configs 或使用者確認作為證據。
- 不確定點分為阻擋問題與可延後確認。
- 長期業務邏輯文件只有在使用者明確要求保存時才建立或更新。

---

## OpenSpec 規則

若專案啟用 OpenSpec：

1. 需求、設計、tasks 與執行狀態都維護在 OpenSpec。
2. 實作前先確認 proposal/design/spec/tasks。
3. 實作過程同步勾選 tasks。
4. 完成後執行 strict validation。
5. 驗證通過後再 archive。

---

## AI Project Index 規則

- `.ai-project-index` 是索引，不是事實來源。
- 用它快速找到候選檔案後，仍須閱讀原始 source、tests、docs 或 specs。
- 修改 source、tests、docs、OpenSpec、project guidance 或 skills 後，若專案有索引流程，應重新整理索引。
