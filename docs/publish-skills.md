# Skill Repo 公開發佈指南

這份文件整理這個 repo 對外公開時的最小發布約定，目標是讓使用者能直接用：

```bash
npx skills add tom54699/agent-skills --skill laravel-api-docs
```

## Canonical Repo

- GitHub owner: `tom54699`
- GitHub repo: `agent-skills`
- 建議 repo 顯示名稱：`Agent Skills`
- 建議 visibility：`public`

## 建議 GitHub 描述

```text
Codex agent skills for Laravel API docs workflows and AI project indexing.
```

## 建議 Topics

- `agent-skills`
- `codex`
- `laravel`
- `openapi`
- `apidog`
- `openspec`

## 公開前檢查

- repo 已設為 public
- README 安裝指令使用 `tom54699/agent-skills`
- README 與 `docs/` 連結皆為 GitHub 可用的相對路徑
- `skills/<skill-name>/` 內每個 skill 都有合法 `SKILL.md` frontmatter
- 若有不想公開列出的 internal skill，已設 `metadata.internal: true`
- 若需要安裝 internal skill，已知要使用 `INSTALL_INTERNAL_SKILLS=1`
- 決定是否補上授權條款檔案，例如 `LICENSE`

## Internal Skills 規則

若 skill 還不想被一般使用者列出或安裝，請在 `SKILL.md` frontmatter 補上：

```yaml
metadata:
  internal: true
```

之後要列出或安裝這類 skill，需先加環境變數：

```bash
INSTALL_INTERNAL_SKILLS=1 npx skills add tom54699/agent-skills --list
INSTALL_INTERNAL_SKILLS=1 npx skills add tom54699/agent-skills --skill <skill-name>
```
