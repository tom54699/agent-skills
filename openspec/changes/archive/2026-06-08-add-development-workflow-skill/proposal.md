## Why

目前 repo 已有 `business-logic-workflow`、`ai-project-index` 與 OpenSpec workflow skills，但缺少一個新專案初始化與日常開發流程的統合入口。使用者希望在新專案用明確指令（例如 `development-workflow init`）建立 AI 協作規則，並讓 AI 知道各 skills 的搭配順序，而不是每個專案重新手寫 `AGENTS.md`、`CLAUDE.md` 與流程說明。

## What Changes

- 新增 `development-workflow` skill，提供新專案初始化與日常開發流程路由。
- 定義 `development-workflow init` 入口，用來產生初始化計畫、建立或更新 `AGENTS.md` / `CLAUDE.md`，並提示必要 skills 安裝。
- 定義新需求、舊專案/重構、純技術小修的 skills 搭配流程。
- 提供可複用的 `AGENTS.md` 與 `CLAUDE.md` 範本資源，讓新專案能快速建立一致的 AI 協作規則。
- 更新 repo 文件與安裝說明，列出 `development-workflow` 的用途與安裝方式。
- 不新增完整自動安裝程式；第一版由 AI 按 skill 指引產生計畫並在確認後修改專案檔案。

## Capabilities

### New Capabilities
- `development-workflow-skill`: 定義 development workflow skill 的 init 入口、skills 搭配流程、專案協作規則範本與日常開發路由。

### Modified Capabilities
- `skill-repo-layout`: 將 `development-workflow` 納入 active project skills 與 repo 文件直屬路徑契約。

## Impact

- 新增 `skills/development-workflow/`。
- 新增 `skills/development-workflow/assets/` 範本。
- 更新 `README.md`、`docs/install-skills.md`、`AGENTS.md`、`CLAUDE.md`。
- 更新 `.ai-project-index/config.json`，讓索引知道新的 skill entrypoint 與範本資源。
- 更新 OpenSpec specs 與 tasks，後續可驗證 skill 存在、文件同步與 init 流程規則。
