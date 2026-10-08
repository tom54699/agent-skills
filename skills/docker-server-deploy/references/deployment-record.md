# 部署紀錄

讓下次修改部署或排查問題時，不必重新盤點一次環境。

## 位置與原則

- 檔案：專案的 `deploy/DEPLOYMENT.local.md`
- **不進 git**：在 `.gitignore` 加上 `deploy/DEPLOYMENT.local.md`
- 需要跨電腦或多人共用時，用 SOPS + age 加密後才 commit（見下方）
- 不寫 secret 的值；只寫 secret 的**名稱**和存放位置

## 範本

```markdown
# <專案> 部署紀錄

更新：<YYYY-MM-DD>
Generated-by: docker-server-deploy v1.0.0

## Server
- 位址：<host>
- SSH：<user>，金鑰在本機的 <path>
- OS / CPU 架構 / CPU / RAM / 磁碟：<...>
- 雲端供應商與防火牆設定：<...>

## 目錄
- DEPLOY_ROOT：<path>
- shared/.env 的變數名稱：<DOMAIN, HEALTH_URL, DATABASE_URL, ...>

## 服務與 image
| 服務 | image | port（127.0.0.1） | 資源限制 |
|---|---|---|---|

## 共享服務
- PostgreSQL：<共享 / 專案自己的>，database：<name>，network：<name>
- Redis / 其他：<...>

## 網域與憑證
- 網域：<domain>
- 憑證：<certbot webroot>，續期：<timer / cron>，deploy hook：<有 / 無>
- Nginx 設定檔：<path>

## CI/CD
- Workflow：.github/workflows/deploy.yml
- Variables：DEPLOY_ENABLED=<true/false>
- Secrets（只寫名稱）：DEPLOY_HOST、DEPLOY_USER、DEPLOY_ROOT、DEPLOY_SSH_KEY、DEPLOY_KNOWN_HOSTS
- server 拉 private image 的方式：<read-only token 存在哪裡>

## 部署與回滾
- 日常：push 到 main
- 手動部署：<DEPLOY_ROOT>/releases/<tag>/deploy.sh <tag>
- 手動回滾：<DEPLOY_ROOT>/current/deploy.sh rollback
- 部署 log：<DEPLOY_ROOT>/shared/logs/

## 變更紀錄
- <YYYY-MM-DD>：<變更內容>
```

## 用 SOPS + age 加密

只在使用者要把紀錄放進 git 時才做。

1. 產生 age 金鑰（私鑰只放本機，另外備份到密碼管理器）：

   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   # 輸出的 public key 開頭是 age1...
   ```

2. 加密，產生要 commit 的檔案：

   ```bash
   sops --encrypt --age <age1-public-key> \
     --input-type binary --output-type json \
     deploy/DEPLOYMENT.local.md > deploy/DEPLOYMENT.enc.json
   ```

3. 在另一台電腦解密（需要同一把私鑰）：

   ```bash
   sops --decrypt --input-type json --output-type binary \
     deploy/DEPLOYMENT.enc.json > deploy/DEPLOYMENT.local.md
   ```

`DEPLOYMENT.local.md` 仍然在 `.gitignore` 裡，只 commit `DEPLOYMENT.enc.json`。每次修改紀錄後重新加密。
