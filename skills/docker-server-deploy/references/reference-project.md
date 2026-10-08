# 和參考專案的差異

範本整理自一個實際運作中的專案（Next.js 前端、Python API、PostgreSQL、向量資料庫，部署在 ARM64 的雲端主機上）。下表區分「參考專案已實作」與「範本新增或調整」。這裡不列出該專案的網域、image 名稱或路徑。

| 項目 | 參考專案已實作 | 範本新增或調整 |
|---|---|---|
| image 建置 | 同一個 repo 建前後端兩個 image；各自的 GHA cache；`latest` 與 `sha-<commit>`；只建 server 的架構 | 沿用，改成 matrix |
| CI 檢查 | lint、typecheck、test、build、對空資料庫跑 migration、Dockerfile 邊界檢查 | 沿用為建議做法（Dockerfile 邊界規則寫在 SKILL.md） |
| 部署版本 | compose 使用 `latest` | 使用 `sha-<commit>`，前後端同一個 tag |
| concurrency | `cancel-in-progress: true`，新的 run 可能中斷進行中的部署 | `cancel-in-progress: false`，server 端再加部署鎖 |
| 設定同步 | `rsync --delete` 到固定目錄（排除 `.env`） | 同步到新的 release 目錄，不需要 `--delete`；`shared/` 永遠不會被碰到 |
| host key | 部署時 `ssh-keyscan` 直接信任 | 預先驗證過的 `DEPLOY_KNOWN_HOSTS` |
| 缺少 secrets | 只給 warning 後跳過 | `DEPLOY_ENABLED` 區分「未啟用 CD」和「設定錯誤（失敗）」 |
| migration | API container 啟動時執行 | 獨立的 migrate job；失敗就中止，服務不受影響 |
| health check | 檢查主機本地的 API 與前端回應 | container healthy、跑的是這次的 tag、外部 HTTPS 也要成功 |
| 失敗處理 | 輸出 logs 後退出 | 自動回滾到上一個 release；另有手動 `rollback` 指令 |
| 舊版本 | 無 | 保留最近幾次的 release 與 image，其餘清理 |
| 共享 PostgreSQL | 以 external network 連線 | 沿用，放在 `optional-modules.md` |
| 部署後同步 job | 同步失敗只警告 | 沿用為可選模組 |
| 專案特定驗收（索引筆數、測試查詢） | 有 | 不列入通用流程 |
| Nginx | 設定檔寫死網域 | 範本只放佔位符，在 server 上用 `envsubst` 產生；另提供第一次申請憑證的 bootstrap |
