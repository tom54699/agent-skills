# Skill 安裝指南

這個 repo 採用多 skill 結構，所有專案 skill 直接放在 `skills/<skill-name>/`：

- `skills/laravel-api-docs/`
- `skills/ai-project-index/`
- `skills/business-logic-workflow/`

## 建議安裝方式

若 repo 已公開到 GitHub，建議直接使用 repo-based 安裝：

```bash
npx skills add tom54699/agent-skills --skill laravel-api-docs
npx skills add tom54699/agent-skills --skill business-logic-workflow
```

常見延伸形式：

```bash
npx skills add tom54699/agent-skills --list
npx skills add tom54699/agent-skills --skill laravel-api-docs --agent codex
npx skills add tom54699/agent-skills --skill laravel-api-docs --global
```

請依你使用的 installer 版本與 agent 類型決定是否需要加上 `--agent`、`--global` 等參數。

## 目前可用 Skill

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
