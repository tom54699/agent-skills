# Agent Skills

這個 repo 用來集中管理多個 agent skill 與其 OpenSpec 變更紀錄，結構上區分穩定可安裝與實驗中 skill，方便後續持續擴充。

## Repo 結構

- `skills/.curated/`：穩定、可推薦安裝的 skill
- `skills/.experimental/`：仍在驗證、可能調整契約的 skill
- `openspec/`：需求、設計、spec、tasks 紀錄
- `docs/`：repo 級文件與安裝說明

## 安裝

公開到 GitHub 後，建議用 repo-based 方式安裝：

```bash
npx skills add <owner>/<repo> --skill laravel-api-docs
```

若要裝給特定 agent 或做全域安裝，再依實際 CLI 需求補上 `--agent`、`--global` 等參數。

完整安裝說明見 [docs/install-skills.md](/Users/athena/Documents/workSpace/私人/Agent-Skills/docs/install-skills.md)。

## Curated Skills

### `laravel-api-docs`

位置：`skills/.curated/laravel-api-docs`

用來跑 Laravel API 文件 guided-sync。流程大致會：

- 先檢查 Laravel 專案環境、Apidog 設定與必要工具
- 根據 Git 變更範圍推測這次受影響的 API
- 和使用者確認最終 API 清單
- 依確認後的清單更新 `openapi.yaml`
- 同步到 Apidog，必要時處理 review 與衝突
- 最後產生多頁 HTML 文件

## Experimental Skills

目前保留 `skills/.experimental/` 結構，之後新增仍在探索中的 skill 時使用。
