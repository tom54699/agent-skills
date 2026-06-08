# Claude Code 協作指引

## 協作原則

1. 使用者是後端工程師，討論與實作以後端視角為主。
2. 全程使用**繁體中文**交流。
3. 避免過度設計，優先滿足當前需求。
4. 任何實作前，先討論並確認需求再執行。
5. 所有專案變更（需求、設計、任務與執行狀態）皆以 OpenSpec 建立並維護紀錄。
6. 文件集中於 `docs/` 管理；功能、API、設定或流程變更都必須同步更新相關文件。

---

## 專案結構導覽

```
Agent-Skills/
├── skills/
│   ├── laravel-api-docs/         # Laravel API 文件同步 skill（主要業務邏輯）
│   │   ├── SKILL.md              # ★ Skill 規格入口，閱讀順序第一
│   │   ├── bin/                  # PHP 執行入口（infer-candidates.php, gen-openapi.php）
│   │   ├── src/                  # PHP 分析器 / 生成器原始碼
│   │   │   ├── InferCandidates/  # 候選 API 推測模組
│   │   │   └── OpenApiGenerator/ # OpenAPI 生成模組
│   │   └── scripts/              # Shell 腳本（progress-lib.sh 等）
│   ├── ai-project-index/         # AI 專案索引 skill
│   └── business-logic-workflow/  # 業務邏輯理解 workflow skill
│
├── .codex/skills/                # OpenSpec workflow skills（流程控制）
│   ├── openspec-explore/         # 探索模式：思考問題，不實作
│   ├── openspec-propose/         # 提案模式：建立 change 並產生所有 artifacts
│   ├── openspec-apply-change/    # 實作模式：執行 tasks
│   └── openspec-archive-change/  # 封存模式：完成後歸檔 change
│
├── openspec/
│   ├── config.yaml               # OpenSpec 設定（schema、context、rules）
│   └── changes/
│       └── archive/              # 已完成的 change 歸檔（歷史參考）
│
└── AGENTS.md                     # 通用 AI 協作原則（本檔來源）
```

---

## 業務邏輯理解流程閱讀順序

### 理解 Laravel API 文件同步功能

閱讀順序（由上至下）：

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/laravel-api-docs/SKILL.md](skills/laravel-api-docs/SKILL.md) | Skill 規格全文，包含完整流程（Step 1–9） |
| 2 | [skills/laravel-api-docs/bin/infer-candidates.php](skills/laravel-api-docs/bin/infer-candidates.php) | 候選推測執行入口 |
| 3 | [skills/laravel-api-docs/bin/gen-openapi.php](skills/laravel-api-docs/bin/gen-openapi.php) | OpenAPI 生成執行入口 |
| 4 | `skills/laravel-api-docs/src/InferCandidates/` | 候選推測模組實作 |
| 5 | `skills/laravel-api-docs/src/OpenApiGenerator/` | OpenAPI 生成模組實作 |

### 理解 OpenSpec 流程

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [openspec/config.yaml](openspec/config.yaml) | 專案的 OpenSpec 設定（schema、規則） |
| 2 | [.codex/skills/openspec-propose/SKILL.md](.codex/skills/openspec-propose/SKILL.md) | 如何提案並建立 change |
| 3 | [.codex/skills/openspec-apply-change/SKILL.md](.codex/skills/openspec-apply-change/SKILL.md) | 如何依 tasks 實作 |
| 4 | [.codex/skills/openspec-archive-change/SKILL.md](.codex/skills/openspec-archive-change/SKILL.md) | 如何歸檔完成的 change |
| 5 | [.codex/skills/openspec-explore/SKILL.md](.codex/skills/openspec-explore/SKILL.md) | 探索/思考模式（不實作） |

### 討論與維護業務邏輯

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/business-logic-workflow/SKILL.md](skills/business-logic-workflow/SKILL.md) | 需求單 brief、舊邏輯 As-Is、As-Is/To-Be/Delta 與保存決策流程 |

業務邏輯理解流程不要求專案採用 DDD 架構，也不要求先有 OpenSpec。需求單、舊功能調查或重構前，應先確認 scope、證據與不確定點；只有使用者明確要求保存時，才更新長期文件。未確認內容不得寫成已確認事實。

---

## Laravel API 文件 Skill 核心流程摘要

Skill 完整規格在 `skills/laravel-api-docs/SKILL.md`，以下為快速索引：

| Step | 名稱 | 關鍵點 |
|------|------|--------|
| 1 | Preflight | 檢查 Laravel 環境、`.env.agents`、必要工具 |
| 2 | 初始化分流 | 有/無 success history 走不同路徑；初始化需確認 `from_commit` 與 `path_strategy` |
| 3 | 變更範圍收斂 | 優先 commit-based diff，fallback 才用時間窗 |
| 4 | 候選 API 推測 | PHP analyzer 主路徑；強/弱訊號模型；結果寫入 `candidates/<timestamp>.json` |
| 5 | 使用者確認清單 | LLM 主導互動；確認後寫 `candidates/<timestamp>.confirmed.json` |
| 6 | 更新 OpenAPI | 依 confirmed 清單深度分析；含 review artifact 流程 |
| 7 | 同步 Apidog | 上傳、衝突處理、post-upload 驗證、寫入 history |
| 8 | 詢問是否產生 HTML | 詢問補充說明需求 |
| 9 | 產生 Redoc HTML | `index.html`（入口）+ `api-docs.html`（純 Redoc） |

**重要規則（閱讀實作前必看）：**
- `docs/api-docs/openapi.yaml` 是 Apidog 同步的唯一來源
- 強訊號可直接產生候選；弱訊號（controller/service method body diff）必須搭配強訊號
- `updated` 衝突預設 `keep_remote`；`missing_remote_endpoint` 為 non-blocking
- post-upload 驗證失敗 → 整次同步視為失敗，不寫 success history

---

## OpenSpec 變更流程

此專案採用 **spec-driven** schema，所有變更須依以下流程進行：

```
探索想法          建立提案          實作任務          歸檔
/opsx:explore  →  /opsx:propose  →  /opsx:apply  →  /opsx:archive
```

變更 artifacts 路徑：`openspec/changes/<name>/`
- `proposal.md` — 做什麼、為什麼
- `design.md` — 怎麼做
- `tasks.md` — 實作步驟
- `specs/<capability>/spec.md` — 能力規格（delta spec）

歸檔後移至：`openspec/changes/archive/YYYY-MM-DD-<name>/`

---

## 目錄慣例（Laravel API Docs Skill 執行時）

| 路徑 | 用途 |
|------|------|
| `docs/api-docs/openapi.yaml` | OpenAPI 規格主檔（唯一同步來源） |
| `docs/api-docs/history/apidog-sync-history.jsonl` | 同步歷史（Step 3 日常流程基準） |
| `docs/api-docs/candidates/<timestamp>.json` | AI 推測候選清單 |
| `docs/api-docs/candidates/<timestamp>.confirmed.json` | 使用者確認後的最終清單 |
| `docs/api-docs/conflicts/<timestamp>.json` | Apidog 衝突清單 |
| `docs/api-docs/reviews/openapi-review.<timestamp>.json` | OpenAPI unresolved review |
| `docs/api-docs/reviews/<timestamp>.approved.json` | Review decision |
| `docs/api-docs/redoc/index.html` | HTML 首頁（分享入口） |
| `docs/api-docs/redoc/api-docs.html` | 純 Redoc API 文件頁 |
| `docs/api-docs/redoc/extra.md` | HTML 補充說明（可選） |
