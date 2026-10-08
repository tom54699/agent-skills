# 可選模組

依專案實際需求套用，不是每個專案都要。動到共用服務會影響其他專案，執行前要先和使用者確認。

## 共享 PostgreSQL

多個專案共用一個 PostgreSQL，部署目錄和專案分開，例如 `/srv/shared-postgres/`。

- 共用的 Docker network 由共享 PostgreSQL 那邊建立（名稱例如 `shared-postgres-network`），專案以 external network 加入
- 每個專案有**自己的 database 和帳號**，不共用 superuser
- 不對外開 port；管理時用 SSH tunnel

專案的 compose：

```yaml
services:
  api:
    networks:
      - app
      - shared-postgres
networks:
  shared-postgres:
    name: shared-postgres-network
    external: true
```

`migrate` 服務也要加入 `shared-postgres` network。

建立專案的 database 與帳號（在共享 PostgreSQL 裡執行，密碼不要出現在對話或 log）：

```sql
CREATE ROLE app_user LOGIN PASSWORD '<PASSWORD>';
CREATE DATABASE app_db OWNER app_user;
REVOKE ALL ON DATABASE app_db FROM PUBLIC;
```

部署前檢查 network 是否存在，不存在就中止，提示先部署共享 PostgreSQL：

```bash
docker network inspect shared-postgres-network >/dev/null 2>&1 \
  || { echo "缺少 shared-postgres-network，請先部署共享 PostgreSQL"; exit 1; }
```

備份：在共享 PostgreSQL 那邊用排程跑 `pg_dump`，備份檔權限 600，並設定保留天數。

## Redis

- **專案自己用**：放在專案的 compose 裡，加上 `mem_limit`，只接內部 network
- **多個專案共用**：每個專案用自己的 key prefix（例如 `app:`）；Redis 6 以上可以用 ACL 給每個專案獨立帳號並限制 key pattern；設定 `maxmemory` 與淘汰策略

## 向量資料庫（例如 Qdrant）

- 資料放固定名稱的 named volume
- 只接內部 network；需要從 server 本機管理時，port 只綁 `127.0.0.1`
- 設定 `mem_limit`，避免吃光小型 server 的記憶體

## 部署後的一次性 job（同步、建索引）

job 放在 `jobs` profile，平常不會啟動：

```yaml
sync:
  image: ghcr.io/<owner>/<project>-api:${RELEASE_TAG:?RELEASE_TAG is required}
  profiles: ["jobs"]
  restart: "no"
  command: ["python", "-m", "app.jobs.sync"]
```

需要在部署成功後自動執行時，加在 `deploy.sh` 的 `cmd_deploy` 裡、`prune_releases` 之後。**失敗只警告**，不影響這次部署的結果：

```bash
compose "$tag" --profile jobs run --rm sync || log "警告：同步失敗，網站服務仍正常，舊的資料仍可使用"
```

專案特定的驗收（例如檢查索引筆數、測試查詢）不要放進核心部署流程。

## 容器 log 輪替

每個服務加上 log 大小限制，避免塞滿磁碟：

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

或在 `/etc/docker/daemon.json` 設定預設值（會影響 server 上所有 container，要先確認）。

## 監控

先評估再加：

- 監控工具本身吃多少 CPU / RAM（小型 server 上很重要）
- 通知送到哪裡（Email、Telegram、Discord…）
- 最簡單的起點：外部的 uptime 檢查，定期打 `HEALTH_URL`
