## Why

使用者有一套實際在跑的部署方式（參考專案：同一個 repo 建前後端兩個 image、GitHub Actions 推到 GHCR、透過 SSH 執行 `deploy.sh`、server 上的 Nginx 處理 HTTPS），`knowledge-platform-dev` 也預定把部署交給一個通用的部署 skill。

目前這套做法只存在單一專案裡，而且有幾個已知缺口：部署沒有固定版本、沒有自動回滾、CI 會取消進行中的部署、手動與 CI 部署可能重疊、`ssh-keyscan` 直接信任主機、缺 secrets 時只給 warning、health check 只檢查本機。需要把它整理成可套用到其他專案的 skill，並補上這些缺口。

## What Changes

- 新增 `docker-server-deploy` skill：
  - 三種模式：首次建置、修改部署、操作與排查
  - 授權範圍：第一次 SSH 前先問；唯讀盤點可直接做；變更照確認過的計畫；刪除資料、改防火牆、改共用服務或影響其他專案一律另外確認
  - 部署紀錄不進 git：本機檔案加入 `.gitignore`，需要共用時用 SOPS + age 加密
  - 網域、host、server 路徑不寫進 repo：範本只放佔位符，實際值來自 server 的 `.env` 或 GitHub Secrets / Variables
  - 範本：GitHub Actions workflow、`deploy.sh`、`docker-compose.yml`、Nginx server block（含第一次申請憑證用的 HTTP bootstrap）、`.env.example`
  - references：第一次申請憑證、migration 與回滾、可選模組（共享 PostgreSQL、Redis、向量資料庫、一次性 job、監控）、Oracle Cloud、部署紀錄、和參考專案的差異對照
- `deploy.sh` 範本相對參考專案新增：release 目錄與 `current` / `previous` 切換、部署鎖、固定 `sha-<commit>` 版本、獨立的 migration 步驟、驗證新 container 版本與外部 HTTPS 的 health check、失敗時自動回滾、手動 `rollback` 指令、清理舊 release
- 測試：
  - `tests/docker-server-deploy/run-tests.sh`：用假的 `docker`、`curl` 模擬，涵蓋成功部署、pull 失敗、migration 失敗、health 逾時與回滾、手動回滾、部署鎖，平常就能在 repo 執行
  - `tests/docker-server-deploy/integration-test.sh`：用真的 Docker（本機 registry），發佈前手動執行
- 更新 repo 文件中的安裝說明、skill 清單與結構導覽

無 **BREAKING** 變更。

## Capabilities

### New Capabilities

- `docker-server-deploy-skill`：部署 skill 的模式、授權範圍、部署紀錄與敏感資訊規則、範本內容、`deploy.sh` 的部署 / 回滾 / 鎖行為、CI/CD 行為、測試要求

### Modified Capabilities

- `skill-repo-layout`：新增 `docker-server-deploy` 以 direct path 發佈的 requirement

## Impact

- 新增：`skills/docker-server-deploy/`（`SKILL.md`、`assets/templates/`、`references/`）、`tests/docker-server-deploy/`
- 更新：`README.md`、`docs/install-skills.md`、`CLAUDE.md`、`AGENTS.md`、`.ai-project-index/config.json`
- 不影響既有 skill；`knowledge-platform-dev` 已預定部署時交給這個 skill
