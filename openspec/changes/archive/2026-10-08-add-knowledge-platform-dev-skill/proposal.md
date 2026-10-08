## Why

使用者要建立一個以「獨立 HTML Artifact」為知識單元的個人 Knowledge Platform，並讓 AI Agent 以 Platform Engineer 的角色建置與維護這個平台。

平台 v1 的架構、登入與存取模型、安全邊界（artifact 獨立 hostname）、備份與部署方式，已經在討論中收斂（細節見 `design.md`）。需要把它們落成一個 skill，避免：

- 每次重新討論同一批架構決策
- Agent 把架構預設當成強制規格，不先盤點使用者既有環境就直接建置
- Agent 在開發平台時順手產生或修改知識內容，混淆「建置平台」與「使用平台」兩類工作

## What Changes

- 新增 `knowledge-platform-dev` skill（Platform Engineer）：
  - 提供平台 v1 **建議架構藍圖**：兩個 hostname（管理 / API 與 artifact 內容分離）、Astro SSR frontend、Go + Chi modular monolith backend、PostgreSQL、bind mount 的 Artifact Storage + X-Accel-Redirect、Redis 選用
  - 藍圖是**建議預設，不是強制規格**；建置前必須先盤點環境並與使用者確認
  - 平台建置後，以平台 repo 的 `docs/architecture.md` 與 API contract 為現況依據，衝突時以 repo 為準
  - 開發規則：handler → service → repository 分層、Storage / BackupTarget interface、DB 變更必附 migration、API 變更必同步 OpenAPI contract、安全相關變更必檢查繞過路徑、必跑測試與建置
  - 定義 **Portable Artifact Format**（`<slug>/` + `metadata.json`），作為平台匯入與備份的格式
  - 知識內容的整理與管理不在這個 skill 的範圍，交給之後新增的 `knowledge-artifact` skill
  - 部署交給之後新增的 `docker-server-deploy` skill；尚未安裝時依藍圖內的部署預設並先與使用者確認
- 更新 repo 文件中的安裝說明、skill 清單與結構導覽

不包含：

- 平台程式碼本身（平台是另一個 repo，由這個 skill 在使用者確認後建置）
- `knowledge-artifact` skill（另開 change）
- `docker-server-deploy` skill（另開 change）

無 **BREAKING** 變更：只新增 skill 與文件，不影響既有 skill。

## Capabilities

### New Capabilities

- `knowledge-platform-dev-skill`：平台開發 skill 的角色與責任邊界、架構藍圖作為建議預設、建置前確認流程、開發規則、安全規則、API contract 同步與部署銜接

### Modified Capabilities

- `skill-repo-layout`：新增 `knowledge-platform-dev` 以 direct path 發佈的 requirement

## Impact

- 新增：`skills/knowledge-platform-dev/`（`SKILL.md` 與 `references/`）
- 更新：`README.md`、`docs/install-skills.md` 的安裝說明與 skill 清單；`CLAUDE.md`、`AGENTS.md` 的結構導覽；`.ai-project-index/config.json` 的 expected coverage
- 不影響既有 skill、腳本或輸出格式
- 沒有 production runtime 影響；平台本身不在這個 repo
