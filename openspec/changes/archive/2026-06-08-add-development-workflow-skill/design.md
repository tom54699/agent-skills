## Context

現有 repo 已有幾個分工明確的 skills：

- `business-logic-workflow`：需求單、舊邏輯、As-Is/To-Be/Delta 與保存決策。
- `ai-project-index`：產生給 AI routing 用的專案索引。
- `.codex/skills/openspec-*`：提案、實作與歸檔流程。

問題不在單一 skill 缺功能，而是新專案或日常開發時缺少一個明確入口告訴 AI：「什麼情境先用哪個 skill、哪些檔案要建立、哪些變更要進 OpenSpec、哪些小修可以走輕量流程」。因此新增 `development-workflow` 作為薄層協調 skill。

## Goals / Non-Goals

**Goals:**
- 提供 `development-workflow init`，在新專案建立 AI 協作規則前先輸出初始化計畫。
- 提供 `AGENTS.md` 與 `CLAUDE.md` 範本，讓新專案可以快速落地一致規則。
- 定義新需求、舊專案/重構、純技術小修與索引更新的 skills 搭配順序。
- 讓 OpenSpec 在需要專案變更紀錄時被使用，但不把所有微小技術調整都硬塞進重流程。

**Non-Goals:**
- 不建立自動安裝所有工具的程式。
- 不取代 `business-logic-workflow` 的業務邏輯整理能力。
- 不取代 OpenSpec workflow skills 的提案、實作、歸檔能力。
- 不強迫所有專案使用同一種技術棧、DDD 架構或文件樹。

## Decisions

### Decision 1: 使用薄層 workflow skill，而不是複製既有 skills

`development-workflow` 只負責分流、初始化與協作規則，不在內部重寫 business logic、OpenSpec 或 indexing 的完整流程。

替代方案是做一個大型總控 skill，將所有流程都收進同一份 `SKILL.md`。這會讓 context 變重，也會讓日後每個子流程變更都需要同步改總控內容。薄層設計可以降低重複與維護成本。

### Decision 2: `init` 先產生計畫，確認後才改專案

新專案初始化會碰到 `AGENTS.md`、`CLAUDE.md`、`docs/`、OpenSpec、索引設定與 skill 安裝。這些是專案政策層級的變更，應先讓使用者看到預計建立/更新的內容，再執行檔案修改。

替代方案是指令一跑就直接全部生成。這比較快，但容易在不同專案產生不合適的規則或覆蓋既有文件。

### Decision 3: 範本放在 `assets/`

`AGENTS.md` 與 `CLAUDE.md` 範本屬於輸出資源，AI 使用時可複製與調整，不需要每次讀入大量參考文件。因此放在 `skills/development-workflow/assets/`，並在 `SKILL.md` 說明使用時機。

### Decision 4: 純技術小修保留輕量路徑

純技術小修定義為不改變使用者可見行為、業務規則、資料意義、API contract、權限、付款、通知與狀態轉移的調整。這類工作可以先確認範圍，必要時不產生完整 business logic brief；但如果 repo 規則要求所有變更進 OpenSpec，仍應遵守該專案的 `AGENTS.md`。

## Risks / Trade-offs

- [Risk] AI 忽略 workflow skill，直接照一般習慣做事。
  → Mitigation: 在 `AGENTS.md` / `CLAUDE.md` 範本加入明確觸發語與情境路由表。

- [Risk] 初始化範本過度通用，落到特定專案不夠貼合。
  → Mitigation: `init` 必須先偵測專案型態與既有文件，再產生計畫，不直接套模板。

- [Risk] 文件越長越難維護。
  → Mitigation: 長期文件只放專案規則與流程入口，業務邏輯仍由 `business-logic-workflow` 先產生 scoped output，再決定是否保存。

- [Risk] skill 安裝需要 network 或使用者環境支援。
  → Mitigation: 第一版只輸出安裝指令與確認清單，不假設 AI 一定能直接完成安裝。
