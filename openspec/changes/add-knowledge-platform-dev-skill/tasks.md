## 1. `knowledge-platform-dev` skill

- [x] 1.1 建立 `skills/knowledge-platform-dev/SKILL.md`：frontmatter（name、含中英文觸發詞的 description、`metadata.version: "1.0.0"`）、角色與責任邊界、知識內容請求轉交 `knowledge-artifact` 的規則
- [x] 1.2 在 SKILL.md 定義 Bootstrap 模式：盤點環境 → 提出建置計畫（沿用 / 新建 / 替換）→ 取得確認 → 建置 → 寫入平台 repo 的 `docs/architecture.md`
- [x] 1.3 在 SKILL.md 定義 Change 模式：先讀 `docs/architecture.md`、API contract、相關程式碼；藍圖與 repo 衝突時以 repo 為準並回報；小需求不做大型重構
- [x] 1.4 在 SKILL.md 定義開發規則：分層、Storage / BackupTarget interface、migration、OpenAPI contract 同步與影響 Agent 端操作的回報、測試與建置
- [x] 1.5 在 SKILL.md 定義安全規則：artifact 獨立 hostname、host-only session cookie、短效預覽 ticket、CSRF 自訂 header 與 CORS、權限只在 backend、credential 儲存方式、安全變更須檢查繞過路徑
- [x] 1.6 在 SKILL.md 定義部署銜接：有 `docker-server-deploy` 就交給它；沒有就依藍圖預設並先盤點、確認
- [x] 1.7 建立 `references/architecture-blueprint.md`：hostname 與安全邊界、元件、Compose service、連線關係、存取模型、登入模型、URL 路由、主要流程、資料表、API、備份、部署預設與備案、架構決策記錄、v1 不包含項目
- [x] 1.8 建立 `references/portable-artifact-format.md`：目錄結構、`metadata.json` 欄位（含 `format_version`、`generated_by`）、匯入與備份規則

## 2. Repo 文件更新

- [x] 2.1 更新 `README.md`：安裝指令加入 `knowledge-platform-dev`，Skills 清單加入說明
- [x] 2.2 更新 `docs/install-skills.md`：安裝指令與「目前可用 Skill」
- [x] 2.3 更新 `CLAUDE.md` 與 `AGENTS.md` 的專案結構導覽，加入 skill 位置與閱讀順序
- [x] 2.4 更新 `.ai-project-index/config.json` 的 `expectedCoverage`，加入新 skill 的 `SKILL.md` 與 `references/*.md`

## 3. 驗證

- [x] 3.1 確認 skill 內沒有任何 secret、使用者實際網域或 server 資訊
- [x] 3.2 執行 `python3 skills/ai-project-index/scripts/refresh-index.py`
- [x] 3.3 執行 `python3 skills/ai-project-index/scripts/evaluate-index.py`
- [x] 3.4 執行 `openspec validate add-knowledge-platform-dev-skill --strict`
- [x] 3.5 執行 `openspec validate --all --strict`
