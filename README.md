# Agent Skills

這個 repo 用來集中管理多個 agent skill 與其 OpenSpec 變更紀錄。所有專案 skill 直接放在 `skills/<skill-name>/`，避免用資料夾名稱區分成熟度造成路徑噪音。

## Repo 結構

- `skills/<skill-name>/`：專案 skill
- `openspec/`：需求、設計、spec、tasks 紀錄
- `docs/`：repo 級文件與安裝說明

## 安裝

公開 repo 後，建議直接用 repo-based 方式安裝：

```bash
npx skills add tom54699/agent-skills --skill development-workflow
npx skills add tom54699/agent-skills --skill laravel-api-docs
npx skills add tom54699/agent-skills --skill business-logic-workflow
```

常見變體：

```bash
npx skills add tom54699/agent-skills --list
npx skills add tom54699/agent-skills --skill laravel-api-docs --agent codex
npx skills add tom54699/agent-skills --skill laravel-api-docs --global
```

## 更新

已安裝過的 skill 可直接使用 `skills` CLI 更新：

```bash
npx skills update laravel-api-docs
```

若當初安裝在全域，使用：

```bash
npx skills update laravel-api-docs -g
```

若當初安裝在專案內，先進入該專案目錄後使用：

```bash
npx skills update laravel-api-docs -p
```

完整安裝說明見 [docs/install-skills.md](docs/install-skills.md)，公開發佈整理見 [docs/publish-skills.md](docs/publish-skills.md)。

## Skills

### `development-workflow`

位置：`skills/development-workflow`

用來初始化新專案的 AI 協作規則，並定義日常開發時各 workflow skills 的搭配順序。主要入口是 `development-workflow init`，會先產生初始化計畫，確認後才建立或更新 `AGENTS.md`、`CLAUDE.md`、文件規則、OpenSpec 規則與索引更新規則。

### `laravel-api-docs`

位置：`skills/laravel-api-docs`

用來跑 Laravel API 文件 guided-sync。流程大致會：

- 先檢查 Laravel 專案環境、Apidog 設定與必要工具
- 根據 Git 變更範圍推測這次受影響的 API
- 和使用者確認最終 API 清單
- 依確認後的清單更新 `openapi.yaml`
- 同步到 Apidog，必要時處理 review 與衝突
- 最後產生多頁 HTML 文件

### `ai-project-index`

位置：`skills/ai-project-index`

產生、查詢與稽核給 AI 使用的輕量專案索引。索引只作為 source/spec/docs/tests 的 routing aid，不是 source of truth。

### `business-logic-workflow`

位置：`skills/business-logic-workflow`

用來引導 AI 與使用者在需求單討論、舊功能理解、重構前調查或新舊邏輯比較時，整理 scoped Business Logic Brief、As-Is、To-Be、Delta、證據與不確定點。它不是自動文件產生器，也不要求先有 OpenSpec；只有使用者明確要求保存時，才討論長期文件落點。

## 參考與致謝

制定 skills 與協作規則時，也參考了社群分享的其他工具：

- [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) — 節錄其 Think Before Coding / Simplicity First / Surgical Changes 三條行為準則，加入根目錄 `AGENTS.md`/`CLAUDE.md` 與 `development-workflow` 的 `AGENTS.template.md` / `CLAUDE.template.md`
- [Understand Anything](https://github.com/Egonex-AI/Understand-Anything) — 另一款程式碼理解工具，用於產生知識圖譜（輸出於本 repo 的 `.understand-anything/`，已列入 `.gitignore`），與本專案的 `ai-project-index` skill 概念相近但非本專案開發
