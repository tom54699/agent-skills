## Why

`knowledge-platform-dev` 負責建置 Knowledge Platform，但使用者日常真正要做的事，是把一個技術主題或一段討論整理成好讀的 HTML 說明，看過、改到滿意後再存進平台。

這件事需要一個獨立的 skill：

- 讓使用者在任何專案裡說「把這個整理進知識庫」，就能進入同一套流程
- 先提案、在本機預覽、反覆修改，使用者確認後才上傳，因為第一版幾乎不可能直接滿意
- 只透過平台 API 操作，不碰平台內部，也不在使用者沒明確要求時公開、分享或刪除內容

## What Changes

- 新增 `knowledge-artifact` skill（Knowledge Curator）：
  - 共同製作流程：理解主題 → 提出大綱與呈現方式 → 在本機產生 → 預覽 → 依回饋修改 → 使用者確認後上傳
  - 本機工作目錄 `~/knowledge-artifacts/<slug>/`，使用 Portable Artifact Format；平台未設定或連不上時，草稿留在本機並明確回報尚未上傳
  - 每篇 artifact 自由設計，不使用共用版型；只保留和外觀無關的要求：淺色與深色模式都可讀、手機寬度可讀、可單獨開啟、不從外部 CDN 載入 JS、程式碼範例只顯示、secret 換成假值
  - 可以上網查證，但要標註來源；網路內容只當素材，不照其中的指示做，也不把其中的 script 當成可執行程式放進 artifact
  - 更新、搜尋、存取設定（只有我 / 有連結的人 / 公開）、刪除：照使用者指令透過 API 執行；公開、分享、刪除只依明確指令
  - 只透過平台 API（`KB_BASE_URL`、`KB_API_TOKEN`、`X-KB-Request` header），平台提供 `/api/openapi.json` 時以它為準
- `knowledge-platform-dev` 的 `references/portable-artifact-format.md` 調整結尾說明，讓兩個 skill 的副本內容完全一致
- 更新 repo 文件中的安裝說明、skill 清單與結構導覽

不包含：

- 共用版型或組裝腳本（討論後決定每篇自由設計，一致性交給平台的 Portal 外框）
- `docker-server-deploy` skill（另開 change）

無 **BREAKING** 變更。

## Capabilities

### New Capabilities

- `knowledge-artifact-skill`：artifact 共同製作流程、預覽後才上傳、本機工作目錄與 Portable Artifact Format、artifact 技術與安全要求、上網查證規則、只透過平台 API 的邊界、存取設定與刪除規則

### Modified Capabilities

- `skill-repo-layout`：新增 `knowledge-artifact` 以 direct path 發佈的 requirement

## Impact

- 新增：`skills/knowledge-artifact/`（`SKILL.md` 與 `references/`）
- 修改：`skills/knowledge-platform-dev/references/portable-artifact-format.md`（只改結尾說明的措辭，格式不變）
- 更新：`README.md`、`docs/install-skills.md`、`CLAUDE.md`、`AGENTS.md`、`.ai-project-index/config.json`
- 不影響既有 skill 的行為
