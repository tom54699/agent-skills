# Skill 安裝指南

這個 repo 採用多 skill 結構，所有專案 skill 直接放在 `skills/<skill-name>/`：

- `skills/laravel-api-docs/`
- `skills/ai-project-index/`
- `skills/business-logic-workflow/`
- `skills/development-workflow/`
- `skills/knowledge-platform-dev/`
- `skills/knowledge-artifact/`
- `skills/docker-server-deploy/`

## 建議安裝方式

若 repo 已公開到 GitHub，建議直接使用 repo-based 安裝：

```bash
npx skills add tom54699/agent-skills --skill development-workflow
npx skills add tom54699/agent-skills --skill laravel-api-docs
npx skills add tom54699/agent-skills --skill business-logic-workflow
npx skills add tom54699/agent-skills --skill knowledge-platform-dev
npx skills add tom54699/agent-skills --skill knowledge-artifact
npx skills add tom54699/agent-skills --skill docker-server-deploy
```

常見延伸形式：

```bash
npx skills add tom54699/agent-skills --list
npx skills add tom54699/agent-skills --skill laravel-api-docs --agent codex
npx skills add tom54699/agent-skills --skill laravel-api-docs --global
```

請依你使用的 installer 版本與 agent 類型決定是否需要加上 `--agent`、`--global` 等參數。

## 目前可用 Skill

### `development-workflow`

- 位置：`skills/development-workflow`
- 用途：初始化新專案 AI 協作規則，並定義新需求、舊邏輯/重構、純技術小修、OpenSpec 與 `.ai-project-index` 的搭配流程
- 主要入口：`development-workflow init`
- 模板：`skills/development-workflow/assets/AGENTS.template.md`、`skills/development-workflow/assets/CLAUDE.template.md`

### `laravel-api-docs`

- 位置：`skills/laravel-api-docs`
- 用途：以 guided-sync 流程同步 Laravel API 文件、Apidog 與 HTML 輸出
- 流程文件：`docs/laravel-api-docs-guided-sync.md`

### `ai-project-index`

- 位置：`skills/ai-project-index`
- 用途：產生、查詢與稽核給 AI 使用的輕量專案索引
- 產物：`.ai-project-index/index.json`、`.ai-project-index/audit.json`

### `business-logic-workflow`

- 位置：`skills/business-logic-workflow`
- 用途：整理需求單 Business Logic Brief、舊邏輯 As-Is、As-Is/To-Be/Delta、證據與不確定點
- 文件目錄：不預設初始化固定目錄；只有使用者明確要求保存時才討論長期文件落點

### `knowledge-platform-dev`

- 位置：`skills/knowledge-platform-dev`
- 用途：建置與維護以獨立 HTML Artifact 為知識單元的個人 Knowledge Platform
- 參考文件：`references/architecture-blueprint.md`（v1 架構藍圖，建議預設）、`references/portable-artifact-format.md`（匯入與備份格式）
- 注意：建置前會先盤點部署環境並和使用者確認；平台建置後以平台 repo 的 `docs/architecture.md` 為準

### `knowledge-artifact`

- 位置：`skills/knowledge-artifact`
- 用途：和 AI 一起把技術主題做成獨立的 HTML 說明，預覽、修改後再上傳到 Knowledge Platform
- 參考文件：`references/platform-operations.md`（API 操作與 curl 範例）、`references/artifact-authoring.md`（製作指引與檢查清單）、`references/portable-artifact-format.md`（本機草稿格式）
- 設定：環境變數 `KB_BASE_URL`、`KB_API_TOKEN`；沒設定或平台連不上時，草稿留在 `~/knowledge-artifacts/<slug>/`
- 安裝建議：日常在各專案都會用到，適合裝在全域（`--global`）

### `docker-server-deploy`

- 位置：`skills/docker-server-deploy`
- 用途：用 Docker Compose、container registry 與 CI/CD 把專案部署到 Linux server；首次建置、修改部署、操作與排查
- 範本：`assets/templates/`（workflow、`deploy.sh`、`docker-compose.yml`、Nginx、`env.example`）
- 參考文件：`references/`（第一次申請憑證、migration 與回滾、可選模組、Oracle Cloud、部署紀錄、和參考專案的差異）
- 測試：`tests/docker-server-deploy/run-tests.sh`（模擬）、`tests/docker-server-deploy/integration-test.sh`（需要 Docker，發佈前執行）

## 更新提醒現況

目前 repo-based 安裝後，skill 不會主動通知使用者有新版本。

- 若要取得更新，需重新執行安裝指令
- 建議關注 repo 的 releases / commit 更新
- 執行期比對遠端版本並提示更新，仍是後續規劃項目

## Internal Skill 規則

如果某個 skill 不想出現在一般 `--list` 或正常安裝流程，請在該 skill 的 `SKILL.md` frontmatter 加上：

```yaml
metadata:
  internal: true
```

之後使用時要先打開 internal skills：

```bash
INSTALL_INTERNAL_SKILLS=1 npx skills add tom54699/agent-skills --list
INSTALL_INTERNAL_SKILLS=1 npx skills add tom54699/agent-skills --skill <skill-name>
```
