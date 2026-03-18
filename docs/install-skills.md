# Skill 安裝指南

這個 repo 採用多 skill 結構，並以 skill 成熟度分層：

- `skills/.curated/`：穩定、可公開推薦安裝
- `skills/.experimental/`：仍在驗證，可能調整名稱、流程或相容性

## 建議安裝方式

若 repo 已公開到 GitHub，建議直接使用 repo-based 安裝：

```bash
npx skills add tom54699/agent-skills --skill laravel-api-docs
```

常見延伸形式：

```bash
npx skills add tom54699/agent-skills --list
npx skills add tom54699/agent-skills --skill laravel-api-docs --agent codex
npx skills add tom54699/agent-skills --skill laravel-api-docs --global
```

請依你使用的 installer 版本與 agent 類型決定是否需要加上 `--agent`、`--global` 等參數。

## 目前可安裝的 Curated Skill

### `laravel-api-docs`

- 位置：`skills/.curated/laravel-api-docs`
- 用途：以 guided-sync 流程同步 Laravel API 文件、Apidog 與 HTML 輸出
- 流程文件：`docs/laravel-api-docs-guided-sync.md`

## 更新提醒現況

目前 repo-based 安裝後，skill 不會主動通知使用者有新版本。

- 若要取得更新，需重新執行安裝指令
- 建議關注 repo 的 releases / commit 更新
- 執行期比對遠端版本並提示更新，仍是後續規劃項目

## Experimental Skill 規則

`skills/.experimental/` 內的 skill 不視為穩定介面。若要公開給其他人安裝，建議先搬到 `skills/.curated/` 後再寫入正式安裝文件。

如果某個 experimental skill 不想出現在一般 `--list` 或正常安裝流程，請在該 skill 的 `SKILL.md` frontmatter 加上：

```yaml
metadata:
  internal: true
```

之後使用時要先打開 internal skills：

```bash
INSTALL_INTERNAL_SKILLS=1 npx skills add tom54699/agent-skills --list
INSTALL_INTERNAL_SKILLS=1 npx skills add tom54699/agent-skills --skill <skill-name>
```
