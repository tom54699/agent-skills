## Context

官方 `skills` CLI 已明確以 repo-based 安裝為主，公開 repo 的主要入口就是 `npx skills add <owner>/<repo>`，多 skill repo 則以 `--skill <skill-name>` 指定。這代表 repo 級文件如果還停留在 placeholder，對外就不算真正可直接安裝。

同時，README 是 GitHub 上的第一個入口，若內含本機絕對路徑或未指定實際 slug，就會讓公開使用者一進 repo 就卡住。

## Goals / Non-Goals

**Goals**
- 讓 repo 文件直接對應目前 GitHub remote `tom54699/agent-skills`。
- 提供可直接公開使用的安裝與發布指引。
- 定義 experimental skill 的公開與隱藏規則。

**Non-Goals**
- 不在這筆 change 變更 GitHub repo 實際設定或 visibility。
- 不新增 npm package、CLI wrapper 或 GitHub Action。
- 不引入法律層面的授權決策，只在文件列為公開前檢查項。

## Decisions

### 1. 以目前 remote 作為 canonical public slug

repo 文件直接使用 `tom54699/agent-skills` 作為安裝指令，避免公開後還要讓使用者自行替換 placeholder。

### 2. README 只放最短安裝入口，細節移到 docs

README 保留最常用指令與 skill 清單；`docs/install-skills.md` 補 `--list`、`--agent`、`--global`、internal skills 等細節；`docs/publish-skills.md` 專門負責 repo 公開發佈規則。

### 3. Experimental skill 以 metadata 控制曝光

若 experimental skill 還不想對一般安裝者曝光，應在 `SKILL.md` frontmatter 加上 `metadata.internal: true`。文件需同步說明 `INSTALL_INTERNAL_SKILLS=1` 才會顯示或安裝這類 skill。

## Risks / Trade-offs

- 若之後 GitHub owner 或 repo 名稱改變，README 與 docs 需一起更新。
- `metadata.internal` 是文件與 skill frontmatter 的共同契約，未來新增 experimental skill 時若忘了加，仍可能被正常列出。

## Migration Plan

1. 補 OpenSpec change。
2. 更新 README 與安裝文件為實際 slug。
3. 新增 repo 公開發佈指引。
4. 驗證文件不再使用本機絕對路徑作為公開連結。
