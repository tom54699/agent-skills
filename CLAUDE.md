# Claude Code 協作指引

## 協作原則

1. 使用者是後端工程師，討論與實作以後端視角為主。
2. 全程使用**繁體中文**交流。
3. 避免過度設計，優先滿足當前需求。
4. 任何實作前，先討論並確認需求再執行。
5. 所有專案變更（需求、設計、任務與執行狀態）皆以 OpenSpec 建立並維護紀錄。
6. 文件集中於 `docs/` 管理；功能、API、設定或流程變更都必須同步更新相關文件。

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

> 此原則適用於單一任務執行過程中的「順手」修改；若使用者明確發起重構/改寫需求，仍依本專案 OpenSpec 變更流程進行，不受此限制。

---

## 專案結構導覽

```
Agent-Skills/
├── skills/
│   ├── laravel-api-docs/         # Laravel 開發收尾 skill（OpenAPI → Apidog → Redoc → Jira）
│   │   ├── SKILL.md              # ★ Skill 規格入口，閱讀順序第一
│   │   ├── scripts/              # Apidog 匯出／資料夾／上傳腳本與 gen-html.sh
│   │   ├── references/           # conventions.md 與 business.md 範本
│   │   └── bin/                  # render-markdown.php（首頁 markdown 轉 HTML）
│   ├── ai-project-index/         # AI 專案索引 skill
│   ├── business-logic-workflow/  # 業務邏輯理解 workflow skill
│   ├── development-workflow/     # 新專案初始化與開發流程統合 skill
│   ├── knowledge-platform-dev/   # 個人 Knowledge Platform 建置與維護 skill
│   ├── knowledge-artifact/       # 技術主題 → HTML 說明 → 上傳平台的 skill
│   └── docker-server-deploy/     # Docker Compose + registry + CI/CD 部署到 Linux server 的 skill
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

### 理解 AI 開發流程統合

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/development-workflow/SKILL.md](skills/development-workflow/SKILL.md) | `development-workflow init`、skills 搭配流程、純技術小修分流與專案協作規則模板 |
| 2 | [skills/development-workflow/assets/AGENTS.template.md](skills/development-workflow/assets/AGENTS.template.md) | 新專案 `AGENTS.md` 範本 |
| 3 | [skills/development-workflow/assets/CLAUDE.template.md](skills/development-workflow/assets/CLAUDE.template.md) | 新專案 `CLAUDE.md` 範本 |

`development-workflow` 是薄層流程入口，用來決定何時使用 `business-logic-workflow`、OpenSpec workflow skills 與 `.ai-project-index`；它不取代這些 specialized skills。

### 理解 Laravel 開發收尾功能

閱讀順序（由上至下）：

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/laravel-api-docs/SKILL.md](skills/laravel-api-docs/SKILL.md) | Skill 規格全文，包含完整流程（Step 0–6） |
| 2 | [skills/laravel-api-docs/scripts/upload-apidog.sh](skills/laravel-api-docs/scripts/upload-apidog.sh) | 上傳前檢查、依資料夾分批上傳、上傳後驗證 |
| 3 | [skills/laravel-api-docs/scripts/apidog-lib.sh](skills/laravel-api-docs/scripts/apidog-lib.sh) | 共用函式：憑證、Apidog 請求、components 修剪、API tree 攤平 |
| 4 | [skills/laravel-api-docs/scripts/export-remote.sh](skills/laravel-api-docs/scripts/export-remote.sh) | 帶 extensions 匯出既有 API |
| 5 | [tests/laravel-api-docs/run-tests.sh](tests/laravel-api-docs/run-tests.sh) | 腳本的模擬測試（修改腳本後必跑） |

修改 `skills/laravel-api-docs/scripts/` 後要跑 `bash tests/laravel-api-docs/run-tests.sh`。腳本要相容 bash 3.2。公司專屬的值（header、錯誤碼、Jira 設定）只放在 Laravel 專案的 `docs/api-docs/conventions.md`，不進本 repo。

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

### 建置與維護 Knowledge Platform

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/knowledge-platform-dev/SKILL.md](skills/knowledge-platform-dev/SKILL.md) | 角色與邊界、Bootstrap / Change 模式、開發與安全規則、部署銜接 |
| 2 | [skills/knowledge-platform-dev/references/architecture-blueprint.md](skills/knowledge-platform-dev/references/architecture-blueprint.md) | v1 架構藍圖（建議預設，含備案與架構決策記錄） |
| 3 | [skills/knowledge-platform-dev/references/portable-artifact-format.md](skills/knowledge-platform-dev/references/portable-artifact-format.md) | 匯入與備份共用的 artifact 格式 |

藍圖是建議預設，不是強制規格；建置前要先盤點環境並和使用者確認。平台建置後，以平台 repo 的 `docs/architecture.md` 為準。

### 製作與管理知識 Artifact

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/knowledge-artifact/SKILL.md](skills/knowledge-artifact/SKILL.md) | 共同製作流程（提案 → 本機預覽 → 修改 → 確認後上傳）、存取設定與刪除規則 |
| 2 | [skills/knowledge-artifact/references/artifact-authoring.md](skills/knowledge-artifact/references/artifact-authoring.md) | 依內容類型的呈現方式、技術與安全要求、檢查清單 |
| 3 | [skills/knowledge-artifact/references/platform-operations.md](skills/knowledge-artifact/references/platform-operations.md) | 平台 API 操作對照、curl 範例、錯誤處理 |

`references/portable-artifact-format.md` 和 `knowledge-platform-dev` 的那份內容必須完全相同，修改時兩份一起更新。

### 部署到 Linux Server

| 順序 | 檔案 | 說明 |
|------|------|------|
| 1 | [skills/docker-server-deploy/SKILL.md](skills/docker-server-deploy/SKILL.md) | 三種模式、授權範圍、部署紀錄與敏感資訊規則、各階段規則 |
| 2 | [skills/docker-server-deploy/assets/templates/deploy.sh](skills/docker-server-deploy/assets/templates/deploy.sh) | release 目錄、部署鎖、migration、health check、自動回滾 |
| 3 | [skills/docker-server-deploy/assets/templates/github-workflow.yml](skills/docker-server-deploy/assets/templates/github-workflow.yml) | test → build → 依序部署 |
| 4 | [tests/docker-server-deploy/run-tests.sh](tests/docker-server-deploy/run-tests.sh) | `deploy.sh` 的模擬測試（修改 `deploy.sh` 後必跑） |

修改 `deploy.sh` 範本後要跑 `bash tests/docker-server-deploy/run-tests.sh`；發佈前在有 Docker daemon 的環境再跑 `bash tests/docker-server-deploy/integration-test.sh`。範本要相容 bash 3.2。

---

## Laravel 開發收尾 Skill 核心流程摘要

Skill 完整規格在 `skills/laravel-api-docs/SKILL.md`，以下為快速索引：

| Step | 名稱 | 關鍵點 |
|------|------|--------|
| 0 | 讀取專案慣例 | `docs/api-docs/conventions.md`；不存在時從參考 API 匯出起草，使用者確認後存檔 |
| 1 | 確認範圍 | git diff + `route:list` 提出本次 API，使用者確認；範圍外不處理 |
| 2 | 撰寫 OpenAPI | AI 讀程式碼撰寫；既有 API 以 Apidog 遠端版本（含 extensions）為底，只改變動處 |
| 3 | 上傳前確認 | 新 API 給摘要、既有 API 給 diff；決定 folder_id；使用者確認 |
| 4 | 上傳 Apidog | 依資料夾分批、移除 `x-apidog-folder`、上傳後驗證路徑與資料夾 |
| 5 | 產生 Redoc | `business.md`（目的、需求、業務邏輯、前端要改什麼）→ `index.html` + `api-docs.html` |
| 6 | Jira 單 | 起草前端／後端單，使用者確認後用當下可用工具建立 |

**重要規則：**
- 每次輸出一個新資料夾 `docs/api-docs/<YYYYMMDD>-<topic>/`，不讀寫舊輸出
- method、path、是否需要認證取自 `route:list`，不推測
- 上傳 Apidog 與建立 Jira 單前一定要使用者確認

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

## 目錄慣例（Laravel 開發收尾 Skill 執行時，位於 Laravel 專案）

| 路徑 | 用途 |
|------|------|
| `.env.agents` | `APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID` |
| `docs/api-docs/conventions.md` | 專案慣例（header、錯誤碼、命名、資料夾習慣等） |
| `docs/api-docs/<YYYYMMDD>-<topic>/openapi.yaml` | 本次範圍的 spec（唯一上傳來源） |
| `docs/api-docs/<YYYYMMDD>-<topic>/remote-base.json` | 範圍內既有 API 的遠端匯出 |
| `docs/api-docs/<YYYYMMDD>-<topic>/upload-targets.json` | 上傳目標與 folder_id |
| `docs/api-docs/<YYYYMMDD>-<topic>/business.md` | 首頁內容 |
| `docs/api-docs/<YYYYMMDD>-<topic>/index.html` | 業務邏輯首頁 |
| `docs/api-docs/<YYYYMMDD>-<topic>/api-docs.html` | 本次 API 的 Redoc 規格頁 |
| `docs/api-docs/<YYYYMMDD>-<topic>/jira.md` | Jira 草稿 |
