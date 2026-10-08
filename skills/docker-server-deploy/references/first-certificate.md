# 第一次申請 TLS 憑證

`nginx.conf.template` 假設憑證已經存在。新網域第一次上線時，先用只開 HTTP 的 bootstrap 設定讓 certbot 完成驗證，再換成完整設定。

修改共用的 Nginx 會影響 server 上的其他專案，每一步動到 Nginx 前都要先和使用者確認。

## 前提

- 網域的 DNS 已經指向 server 的公網 IP
- 80 和 443 port 在**雲端安全規則**和**主機防火牆**兩邊都已開放（Oracle Cloud 見 `oracle-cloud.md`）
- server 已安裝 Nginx 和 certbot

## 步驟

1. 確認 DNS：

   ```bash
   dig +short app.example.com   # 結果要是 server 的公網 IP
   ```

2. 準備 webroot：

   ```bash
   sudo mkdir -p /var/www/certbot
   ```

3. 套用 bootstrap 設定（只讀 `DOMAIN`，不要 source 整個 `.env`）：

   ```bash
   export DOMAIN="$(sed -n 's/^DOMAIN=//p' <DEPLOY_ROOT>/shared/.env)"
   envsubst '${DOMAIN}' < nginx-bootstrap.conf.template \
     | sudo tee /etc/nginx/sites-available/<project>.conf > /dev/null
   sudo ln -sfn /etc/nginx/sites-available/<project>.conf /etc/nginx/sites-enabled/<project>.conf
   sudo nginx -t && sudo systemctl reload nginx
   ```

4. 申請憑證：

   ```bash
   sudo certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN"
   ```

5. 換成完整設定（`nginx.conf.template` 開頭有完整指令），一樣先 `sudo nginx -t` 再 reload。

   `options-ssl-nginx.conf` 和 `ssl-dhparams.pem` 是 certbot nginx plugin 產生的檔案。只用 webroot 時可能不存在，這時刪掉範本裡那兩行，改成自己設定：

   ```nginx
   ssl_protocols TLSv1.2 TLSv1.3;
   ssl_session_cache shared:SSL:10m;
   ```

6. 確認續期：

   ```bash
   sudo certbot renew --dry-run
   ```

   續期後要 reload Nginx 才會用新憑證。加一個 deploy hook：

   ```bash
   printf '#!/bin/sh\nsystemctl reload nginx\n' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh > /dev/null
   sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
   ```

7. 驗收：

   ```bash
   curl -I "https://$DOMAIN/"
   curl -I "http://$DOMAIN/"     # 應該 301 到 https
   ```

## 動態 DNS

使用 DuckDNS 這類動態 DNS 時，依供應商的說明設定 IP 更新排程（例如 cron 每 5 分鐘呼叫一次更新 API），token 放在 server 上權限 600 的檔案裡，不要寫進 crontab 或 repo。

## 不建議用 `certbot --nginx`

`--nginx` plugin 會自動改寫 Nginx 設定。server 上的 Nginx 由多個專案共用時，自動改寫可能動到其他專案的設定，所以預設用 `certonly --webroot`。使用者明確要求時才用 plugin。
