# Agent Skills

這個 repo 用來集中管理多個 agent skill 與其 OpenSpec 變更紀錄，結構上區分穩定可安裝與實驗中 skill，方便後續持續擴充。

## Repo 結構

- `skills/.curated/`：穩定、可推薦安裝的 skill
- `skills/.experimental/`：仍在驗證、可能調整契約的 skill
- `openspec/`：需求、設計、spec、tasks 紀錄
- `docs/`：repo 級文件與安裝說明

## 安裝

公開 repo 後，建議直接用 repo-based 方式安裝：

```bash
npx skills add tom54699/agent-skills --skill laravel-api-docs
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

若某個 experimental skill 不想被一般安裝流程列出，請在該 skill 的 `SKILL.md` frontmatter 補上 `metadata.internal: true`。
