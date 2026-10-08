## Context

使用者提供了參考專案的部署交接資料：workflow、`deploy.sh`、`docker-compose.yml`、Nginx 設定與兩個 Dockerfile，以及 10 個通用範本必須補齊的缺口。這個 change 把它整理成通用的 `docker-server-deploy` skill。

限制條件：

- skill 會公開，範本不能帶任何專案的網域、image 名稱、server 路徑
- 使用者不希望部署紀錄進 git；要進 git 就必須加密
- 這個 skill 會透過 SSH 操作真正的 server，授權範圍要明確
- 測試環境是 macOS：內建 bash 3.2、沒有 `flock`；Docker Desktop 有安裝但不一定在執行

## Goals / Non-Goals

**Goals:**

- 把參考專案的模式整理成可套用到其他專案的範本與流程
- 補上 10 個缺口
- `deploy.sh` 的部署、回滾、鎖行為有自動化測試

**Non-Goals:**

- 不支援 Kubernetes、Swarm 或多台 server
- 不自動回滾資料庫
- 不提供監控系統的完整設定，只在 references 說明評估方式

## Decisions

### D1：三種模式

| 模式 | 什麼時候用 |
|---|---|
| 首次建置 | 新專案第一次上線：盤點 → 計畫 → 確認 → 建立範本檔、server 目錄、Nginx、憑證、secrets → 首次部署 → 驗收 → 寫部署紀錄 |
| 修改部署 | 加 service、換網域、改 CI/CD：讀部署紀錄 → 變更計畫 → 確認 → 修改 → 驗收 |
| 操作與排查 | 手動回滾、查失敗原因、看 log：讀部署紀錄 → 只做使用者要求的操作 |

CI/CD 建好後，日常部署就是 push 到 main，不需要這個 skill 介入。

### D2：授權範圍

- 第一次 SSH 連線前先問使用者
- 使用者同意連線後，唯讀盤點（`docker ps`、看設定、看磁碟）可以直接做
- 變更只照使用者確認過的計畫執行；計畫外的變更另外問
- 刪除資料 / volume / image、改防火牆、改共用的 Nginx / PostgreSQL / Redis、影響其他專案：一律另外確認

### D3：部署紀錄與敏感資訊

- 部署紀錄放在專案的 `deploy/DEPLOYMENT.local.md` 並加入 `.gitignore`；需要跨電腦或多人共用時，用 SOPS + age 加密成 `deploy/DEPLOYMENT.enc.json` 再 commit（SOPS 以 binary 模式加密任意檔案時，輸出是 JSON）
- repo 裡的檔案只放佔位符：網域、host、使用者、server 路徑都不寫進 git
  - server 端的值放在 `shared/.env`（權限 600）
  - CI 用的值放在 GitHub Secrets（`DEPLOY_HOST`、`DEPLOY_USER`、`DEPLOY_ROOT`、`DEPLOY_SSH_KEY`、`DEPLOY_KNOWN_HOSTS`）與 Variables（`DEPLOY_ENABLED`）
  - Nginx 設定在 server 上用 `envsubst` 從範本產生，只替換指定的變數，避免動到 Nginx 自己的 `$host` 等變數
- secret 的值不出現在對話與 log：`gh secret set` 從 stdin 或檔案讀取

### D4：release 目錄

```
<DEPLOY_ROOT>/
├── releases/<sha-commit>/   每次部署由 CI 同步到新目錄
├── current  -> releases/...
├── previous -> releases/...
├── shared/                  .env、logs、backups；同步永遠不會碰到
├── .release-history         每次部署嘗試的 tag，一行一個
└── .deploy.lock/            部署鎖
```

- CI 同步到新的 release 目錄，不會覆蓋正在執行的版本，所以同步本身不需要鎖；也不需要 `rsync --delete`，自然保護 `shared/`（缺口 4、9）
- compose 的 `name:` 固定專案名稱，不同 release 目錄才會被當成同一個 compose 專案；持久資料只用固定名稱的 named volume 或 `shared/` 的絕對路徑
- 成功後清理舊 release：保留 `.release-history` 最後 `KEEP_RELEASES`（預設 5）筆、`current`、`previous`；其餘**曾經嘗試部署過**的目錄連同該 tag 的 image 一起移除（image 移除失敗只警告）。剛同步上來、還沒部署過的目錄不在 history 裡，不會被清掉，避免手動部署與 CI 同步交錯時刪到別人的 release

### D5：部署鎖用 mkdir

`mkdir` 建立鎖目錄是原子操作，鎖目錄裡寫入持有者的 pid；拿不到鎖時檢查 pid 是否還活著，已經不在就視為殘留鎖並移除。等待超過 `LOCK_WAIT`（預設 600 秒）就以 exit code 75 結束。

考慮過的替代方案：`flock`。Linux 上很好用，但 macOS 沒有，測試與 B 的整合測試都在 macOS 上執行；用 mkdir 只有一套實作，兩邊行為一致。

GitHub Actions 端另外用 `concurrency`（`cancel-in-progress: false`）讓 CI 部署排隊，不會取消進行中的部署（缺口 3）。

### D6：`deploy.sh` 流程

```
deploy.sh [<tag>]
  1. 取得部署鎖
  2. 檢查：shared/.env 存在、compose 設定有效
  3. pull 這個 tag 的 image            → 失敗：中止，什麼都沒動
  4. 執行一次性 migrate job            → 失敗：中止，服務沒動；回報資料庫可能部分 migrate
  5. current 指向新 release，啟動服務
  6. health check（直到 HEALTH_TIMEOUT）：
     - 每個 app 服務的 container 是 healthy（沒有 healthcheck 時要是 running）
     - container 的 image 是這次的 tag
     - 有設定 HEALTH_URL 時，外部 HTTPS 也要回應成功
  7. 成功：previous 指向舊版、寫入 history、清理舊 release
     失敗：自動切回舊版並啟動、重新做 health check
           回滾成功 → exit 1；回滾也失敗 → exit 2；沒有舊版可回 → exit 1

deploy.sh rollback
  在鎖內把 current 與 previous 對調，啟動並做 health check；不跑 migration
```

- 版本固定：compose 用 `${RELEASE_TAG}`，前後端同一個 `sha-<commit>`（缺口 2）
- 自動回滾只切 image 與設定，不回滾資料庫（缺口 1、7）
- health check 驗證新版本與外部 HTTPS（缺口 8）
- 為了在 macOS 測試，`deploy.sh` 相容 bash 3.2

### D7：migration 是部署裡獨立的一步

compose 裡有一個 `migrate` 服務：用 API image、放在 `jobs` profile、只換 command。`deploy.sh` 在切換服務前執行它。

和參考專案「container 啟動時跑 migration」相比：migration 失敗時舊版服務完全沒被動到；container 重啟時也不會重跑 migration。代價是專案 Dockerfile 的 CMD 不再負責 migration。

資料庫不回滾。skill 只要求：migration 盡量向下相容（先加欄位、下一版再刪）；這次部署包含刪欄位等破壞性 migration 時，部署前告訴使用者並建議先備份。

### D8：CI/CD workflow

- `test` → `build`（matrix：每個 image 一個 job、各自的 GHA cache scope、打 `latest` 與 `sha-<commit>`）→ `deploy`
- `deploy` 只在 main 且 `vars.DEPLOY_ENABLED == 'true'` 時執行；沒開時由 `deploy-disabled` job 輸出「未啟用 CD」的 notice；開了但缺 secret 就讓 job 失敗（缺口 6）
- SSH 使用預先驗證過的 `DEPLOY_KNOWN_HOSTS`，`StrictHostKeyChecking=yes`，不用 `ssh-keyscan`（缺口 5）
- action 與 image 版本沿用參考專案的快照，並在範本註明使用前依目標環境確認（交接要求）

### D9：參數分兩類

| 類型 | 例子 | 放在哪裡 |
|---|---|---|
| 建立部署時填入（不敏感） | 專案名稱、image 名稱、服務名稱、port、health 路徑、migration 指令 | 直接寫進專案的 `deploy/` 檔案 |
| 執行時提供（敏感） | 網域、host、使用者、server 路徑、SSH key、資料庫密碼 | server 的 `shared/.env`、GitHub Secrets |

範本用 `__PROJECT__`、`__OWNER__` 這類佔位符表示第一類。

### D10：可選模組

共享 PostgreSQL（external network、每個專案獨立的 database 與帳號）、Redis（key prefix）、向量資料庫、部署後的同步 job（失敗只警告）、監控，都放在 `references/optional-modules.md`，有需要才套用（缺口 10）。參考專案的知識索引驗收不列入通用流程。

### D11：測試

- **A：`tests/docker-server-deploy/run-tests.sh`**：在 PATH 前面放假的 `docker` 與 `curl`，用環境變數決定每次呼叫的結果，並把「目前執行中的 tag」記在狀態檔。涵蓋：首次與第二次部署成功、pull 失敗、migration 失敗、health 逾時與自動回滾、container image 不對而回滾、手動 `rollback`、鎖被佔用、殘留鎖、缺少 `.env`、清理舊 release。不需要 Docker，平常就能跑
- **B：`tests/docker-server-deploy/integration-test.sh`**：啟動本機 registry，推兩個測試 tag，用真的 `docker compose` 跑成功部署、pull 失敗、migration 失敗、health 失敗回滾、手動回滾。需要 Docker daemon，發佈前手動執行

### D12：和參考專案的差異對照

`references/reference-project.md` 列出「參考專案已實作」與「範本新增」的對照，不放任何專案的網域、image 名稱或路徑。

## Risks / Trade-offs

- [mkdir 鎖遇到 pid 被重複使用] → 機率極低；鎖目錄同時記錄建立時間，排查時可判斷
- [資料庫不回滾，破壞性 migration 後自動回滾可能讓舊版壞掉] → 要求向下相容的 migration；破壞性 migration 前先告知並備份
- [範本的 action / image 版本過期] → 範本註明使用前確認版本
- [envsubst 替換到 Nginx 自己的變數] → 只替換列出的變數
- [B 測試需要 Docker 與網路] → 平常只跑 A；B 在發佈前手動執行

## Migration Plan

只新增 skill、範本與測試。撤回時刪除 `skills/docker-server-deploy/`、`tests/docker-server-deploy/` 並還原文件清單。

## Open Questions

- 無阻擋問題。
