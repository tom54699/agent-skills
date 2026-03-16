## Why

目前 repo 結構已經整理成多 skill collection，但對外安裝文件還停留在 placeholder 狀態，沒有直接使用實際公開 slug。另一方面，repo 也還缺少一份明確的公開發佈指引，說明 GitHub repo 應如何呈現、README 應如何寫、以及 experimental skill 何時要隱藏。

若現在不補齊，之後即使 repo 已公開，使用者仍需要自己猜安裝指令或從文件裡替換 `<owner>/<repo>`，也容易因 README 使用本機路徑連結而在 GitHub 上失效。

## What Changes

- 將 README 與安裝文件改為使用實際公開 slug `tom54699/agent-skills`。
- 新增公開發佈指引，整理 repo 名稱、描述、topics、visibility 與發布前檢查。
- 補上 experimental skill 的公開規則，說明何時使用 `metadata.internal: true` 與 `INSTALL_INTERNAL_SKILLS=1`。

## Capabilities

### Added Capabilities
- `skill-repo-public-distribution`: repo MUST 提供可直接複製使用的公開安裝命令與公開發佈指引。

## Impact

- 影響 `README.md`
- 影響 `docs/install-skills.md`
- 新增 `docs/publish-skills.md`
