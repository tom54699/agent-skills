# Migration 與回滾

## Migration 是部署裡獨立的一步

`deploy.sh` 在切換服務**之前**執行 compose 裡的一次性 `migrate` 服務：

```yaml
migrate:
  image: ghcr.io/<owner>/<project>-api:${RELEASE_TAG:?RELEASE_TAG is required}
  profiles: ["jobs"]
  restart: "no"
  command: ["alembic", "upgrade", "head"]   # Laravel: ["php", "artisan", "migrate", "--force"]
  environment:
    DATABASE_URL: ${DATABASE_URL:?DATABASE_URL is required}
  networks:
    - app
```

和「container 啟動時跑 migration」相比：

| | 啟動時跑 | 獨立一步 |
|---|---|---|
| migration 失敗 | 舊 container 已經被換掉，新的一直重啟失敗，網站停擺 | 還沒動到服務就中止，舊版照常運作 |
| container 重啟 | 每次重啟都再跑一次 | 只在部署時跑一次 |
| 錯誤訊息 | 混在重啟 log 裡 | 就是部署失敗的原因 |

所以應用程式的 Dockerfile CMD **不要**再跑 migration。專案沒有 migration 時，把 `deploy.sh` 的 `MIGRATE_SERVICE` 設成空字串。

## Migration 失敗時

部署中止，服務沒有變更。但資料庫可能已經**部分 migrate**：

- PostgreSQL 的 DDL 可以包在 transaction 裡，多數 migration 工具會整批 rollback
- MySQL 的 DDL 會自動 commit，失敗時前面的變更已經生效

處理方式：查 migration 工具的版本紀錄表（例如 `alembic_version`、Laravel 的 `migrations`），確認實際停在哪一步，修正後重新部署。

## 自動回滾做什麼、不做什麼

| | 會回滾 | 不會回滾 |
|---|---|---|
| image（前後端） | ✓ 切回上一個 release 的 `sha-<commit>` | |
| compose 與部署設定 | ✓ 用上一個 release 目錄的檔案 | |
| 資料庫 schema 與資料 | | ✗ |
| `shared/.env` | | ✗（所有 release 共用） |
| volume 裡的檔案 | | ✗ |

所以自動回滾能不能救回來，取決於**舊版程式能不能在新的 schema 上執行**。

## 讓 migration 向下相容

| 想做的事 | 向下相容的做法 |
|---|---|
| 新增欄位 | 允許 NULL 或給預設值 |
| 改欄位名稱 | 這一版新增新欄位並同時寫兩邊；下一版改讀新欄位；再下一版刪舊欄位 |
| 刪欄位 | 這一版先讓程式不再使用；下一次部署才刪 |
| 改型別 | 新增新型別的欄位並搬資料，比照改名 |

## 破壞性 migration

刪欄位、改型別、刪資料這類 migration 一旦執行，舊版程式通常就不能用了。部署前：

1. 告訴使用者這次包含破壞性 migration，舊版無法自動回滾
2. 建議先備份，例如：

   ```bash
   docker exec <postgres-container> pg_dump -U <user> -Fc <db> \
     > <DEPLOY_ROOT>/shared/backups/<db>-$(date +%Y%m%d-%H%M%S).dump
   chmod 600 <DEPLOY_ROOT>/shared/backups/*.dump
   ```

3. 使用者確認後才部署
4. 出問題時：還原備份（`pg_restore`）後再手動回滾，或修正後重新部署

## 手動回滾

```bash
<DEPLOY_ROOT>/current/deploy.sh rollback
```

在部署鎖裡把 `current` 和 `previous` 對調，啟動並做 health check。不跑 migration，資料庫不會回滾。
