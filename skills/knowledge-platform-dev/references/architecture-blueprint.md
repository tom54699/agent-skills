# Knowledge Platform 架構藍圖（v1）

> 這份藍圖是**建議預設**，不是強制規格。建置前要先盤點部署環境，並和使用者確認哪些沿用、哪些新建、哪些替換。
>
> 平台建置後，以平台 repo 的 `docs/architecture.md` 為準。Bootstrap 時，把確認後的版本寫進那份文件。
>
> 文中的 `kb.example.com`、`content.example.com`、`/srv/knowledge/` 都是範例，實際值由使用者決定。

## 1. 系統定位

個人知識平台。每份知識是一個獨立的 HTML Artifact，自帶 CSS、JS 和 assets，可以搜尋、分類，並透過分享連結或公開的方式給別人看。

- 只有擁有者（Owner）一個人能登入、上傳和管理
- 內容主要由 AI Agent 產生，再透過 API 上傳
- 其他人只能閱讀：瀏覽公開列表、打開公開 artifact，或打開分享連結。他們沒有帳號，也不用登入
- 不是 Blog、不是 Markdown 筆記系統、不是 Notion Clone

## 2. 角色

| 角色 | 怎麼驗證身分 | 能做什麼 |
|---|---|---|
| Owner（瀏覽器） | 密碼 + TOTP（例如 Google Authenticator），登入後拿到 session cookie，有效 30 天 | 所有管理操作 |
| AI Agent（在 Owner 的電腦上執行） | 每個請求都帶 `Authorization: Bearer <PAT>` | 透過 API 建立、更新、搜尋 artifact，以及設定存取權限 |
| 分享連結訪客 | 網址裡的隨機 token | 只能看那一篇 |
| 公開訪客 | 不驗證 | 公開列表頁和公開的 artifact |

## 3. 網域與元件

### 3.1 兩個 hostname

| Hostname | 用途 | 登入狀態 |
|---|---|---|
| `kb.example.com` | 公開列表頁、管理介面、API | Owner 的 session cookie 只存在這個 hostname（host-only cookie） |
| `content.example.com` | 只送出 artifact 的內容 | 沒有任何登入狀態 |

為什麼要分開：artifact 是 AI 產生的任意 HTML + JS，可能因為 prompt injection 而含有惡意程式。放在另一個 hostname，這些 JS 就沒辦法用 Owner 的登入身分呼叫 API。

### 3.2 元件

| 元件 | 歸屬 | 職責 |
|---|---|---|
| 反向代理（預設：共用 Nginx） | server 上既有的基礎設施，沒有才新建 | 處理兩個 hostname 的 TLS；依 hostname 和路徑轉給前端或後端；在 content hostname 用 internal location 從 bind mount 讀 artifact 檔案，只接受 X-Accel-Redirect |
| frontend container（Astro，用 Node 執行 SSR） | 平台，例如 `node:22-alpine`，監聽 :4321 | 公開列表頁和管理介面；頁面在 server 端產生；沒登入時導向登入頁（只為了使用體驗，權限還是由 backend 判斷） |
| backend container（Go + Chi） | 平台，監聽 :8080 | 提供 API、驗證身分、判斷權限、簽發短效預覽網址、回傳 X-Accel-Redirect、把上傳的檔案寫進 storage；也提供 CLI（migration、備份、匯入、設定密碼和 TOTP、產生 token） |
| PostgreSQL | 官方 image；server 上已經有就沿用 | 存帳號、token、metadata、版本、分享、tag、log |
| Artifact Storage | 平台的資料，bind mount 到專案目錄，例如 `/srv/knowledge/data/artifacts` | 存 HTML 檔案本體，透過 Storage interface 存取，之後可以換成 S3、MinIO 或 R2 |
| Redis | 選用；server 上已經有就沿用 | v1 用不到，有具體需求才加 |
| CI/CD 與 registry（預設：GitHub Actions + GHCR） | GitHub | 跑測試、建置兩個 image、推到 registry、透過 SSH 部署 |
| 備份目標（預設：private GitHub repo） | 另一個 repo | 接收每天匯出的備份 |

Go 內部模組（`backend/internal/`）：`auth`、`artifact`、`access`、`tag`、`search`、`audit`、`backup`。每個模組都分成 handler → service → repository 三層。`storage` 和備份目標（`BackupTarget`）各自是獨立的 interface。不要拆成 microservices。

### 3.3 Docker Compose 的 service

| service | image | 執行方式 | 說明 |
|---|---|---|---|
| frontend | 平台的 frontend image | 常駐 | Astro Node server |
| backend | 平台的 backend image | 常駐 | Go API，同時處理兩個 hostname 的請求 |
| postgres | 官方 postgres | 常駐 | 沿用 server 既有的話就不需要 |
| redis | 官方 redis | 選用 | v1 用不到 |
| migrate | backend image | 一次性 | 部署時執行 migration |
| backup | backend image | 一次性，由排程觸發 | 匯出並送到備份目標 |

container 的 port 只綁在 `127.0.0.1`，不直接對外。如果共用 Nginx 本身也是 container，改用共享的 Docker network 連線。

### 3.4 元件之間的連線

- 所有外部請求 → 反向代理（HTTPS，兩個 hostname）
- kb hostname：`/api/*` → backend（127.0.0.1:8080）；其他所有路徑 → frontend（127.0.0.1:4321）
- content hostname：`/a/*`、`/s/*`、`/p/*` → backend
- frontend → backend：在 server 端產生頁面時，透過 Docker 內部網路呼叫 API（例如公開列表、檢查登入狀態）
- backend → PostgreSQL：讀寫資料
- backend → Artifact Storage：上傳時寫入
- backend → 反向代理：artifact 的請求只回傳 `X-Accel-Redirect` header
- 反向代理（content）→ Artifact Storage：由 internal location 唯讀讀檔
- backup job（backend image）→ 備份目標：每天送出
- AI Agent → backend API（經過 kb hostname）
- CI → registry：推送兩個 image；CI → server（SSH）：執行 `deploy.sh`；server → registry：拉取 image

```
              Owner 瀏覽器 / 訪客 / AI Agent
                            │ HTTPS
             ┌──────────────┴───────────────┐
             ▼                              ▼
      kb.example.com               content.example.com
       （反向代理）                    （反向代理）
       │           │                │           ▲           │
       │ / /admin  │ /api           │ /a /s /p  │ X-Accel   │ internal 唯讀
       ▼           ▼                ▼           │           ▼
  ┌──────────┐  ┌────────────────────────────────┐   ┌──────────────────┐
  │ frontend │─▶│        backend（Go :8080）     │──▶│ Artifact Storage │
  │ (:4321)  │  └────────────────────────────────┘寫入│  (bind mount)    │
  └──────────┘          │                 │          └──────────────────┘
                        ▼                 ▼ 每天
                 ┌────────────┐   ┌──────────────────┐
                 │ PostgreSQL │   │   備份目標       │
                 └────────────┘   └──────────────────┘
                 （Redis：選用）
```

## 4. 存取模型

### 4.1 兩個獨立的概念

- **visibility**：`private`（預設）或 `public`
- **分享連結**：每篇最多一條有效的連結

權限判斷（content hostname，每種路徑只檢查自己的條件）：

```
/a/<slug>/    → artifact 是 public 才送出
/p/<ticket>/  → 預覽 ticket 有效（Owner 專用）才送出
/s/<token>/   → 分享 token 有效、沒過期、沒撤銷才送出
其他          → 404
```

### 4.2 畫面與 API 上的三個選項

| 選項 | 實際狀態 |
|---|---|
| `only_me`（只有我） | private，沒有有效的分享連結（選這個時，後端會同時撤銷連結） |
| `link`（有連結的人） | private + 一條有效的分享連結 |
| `public`（公開） | public（分享連結維持原狀），並出現在公開列表頁 |

### 4.3 分享連結的規則

- 每篇最多一條有效連結；再要一次分享時，給的還是同一條
- 到期時間可以不設；設了之後隨時可以改或取消，連結不會變
- 撤銷後永久失效；之後再建立會產生新的 token
- token 是至少 128 bit 的隨機字串。DB 存兩個欄位：`token_hash` 用來查詢；`token_encrypted` 用來在管理介面再次顯示原本的連結
- 刪除 artifact 是另外的操作（soft delete），和改存取設定分開

### 4.4 Owner 預覽私人 artifact

- Owner 在管理介面打開私人 artifact 時，backend 發一個短效網址 `content.example.com/p/<ticket>/`
- ticket 用 HMAC 簽章，內容是 artifact id 和到期時間，不存進 DB；例如 30 分鐘內有效，而且只能看那一篇
- 管理介面用 iframe 或新分頁打開
- 不在 content hostname 設登入 cookie：有了 cookie，一篇惡意 artifact 就能讀到 Owner 其他的私人 artifact。用 ticket 的話，影響範圍只有那一篇

## 5. 驗證身分

**Owner（瀏覽器）**

- 登入頁只有兩個欄位：密碼和 6 位數 TOTP。只有一個使用者，所以沒有帳號欄位
- 用 CLI 設定：`server set-password`；`server setup-totp`（在終端機顯示 QR code，用手機掃描）
- 密碼用 bcrypt 存；TOTP secret 加密後存放
- 限制登入失敗次數，次數記在記憶體（單一 backend instance，不需要 Redis）
- Session 存在 PostgreSQL，有效 30 天，可以一次登出所有裝置
- Session cookie：只發給 kb hostname（不設 `Domain` 屬性），加上 `HttpOnly`、`Secure`、`SameSite=Lax`
- 手機遺失：在 server 上用 CLI 重新設定 TOTP

**AI Agent（PAT）**

- 格式是 `kbp_` 加上隨機字串，DB 只存 SHA-256 hash
- 登入後在管理介面的設定頁建立或撤銷；第一把也可以用 CLI `server create-token` 產生
- Agent 端用環境變數 `KB_BASE_URL`、`KB_API_TOKEN`

**擋下跨站請求（CSRF）**

- 所有會修改資料的 API 請求，都必須帶自訂 header `X-KB-Request: 1`
- API 不對 content hostname 開放 CORS
- 原因：兩個子網域在瀏覽器看來屬於同一個網站（same-site），cookie 還是可能被帶上。要求自訂 header 之後，瀏覽器會先發 preflight 請求，而 API 不允許 content hostname，這類請求就會被擋下

**加密金鑰（`APP_ENCRYPTION_KEY`）**

- 用來加密 TOTP secret 和分享 token
- 放在 server 的 `.env`；Owner 要另外保存一份（例如存在密碼管理器）
- 還原備份時需要同一把金鑰，否則分享連結要重新產生

**v1 不做：** 註冊、多使用者、第三方登入、passkey、PAT scope

## 6. URL 路由

**kb hostname**

| Path | 轉給誰 | 說明 |
|---|---|---|
| `/api/*` | backend | 依 endpoint 檢查 session 或 PAT |
| `/` | frontend | 公開列表頁 |
| `/admin/...` | frontend | 管理介面；沒登入就導向 `/admin/login` |

**content hostname**

| Path | 轉給誰 | 說明 |
|---|---|---|
| `/a/<slug>/...` | backend 檢查後回傳 X-Accel | 只送出 public 的 artifact |
| `/s/<token>/...` | backend 檢查 token 後回傳 X-Accel | token 要有效、沒過期、沒撤銷 |
| `/p/<ticket>/...` | backend 檢查 ticket 後回傳 X-Accel | Owner 的短效預覽 |
| `/_artifacts/...` | 反向代理 internal location（alias 到 bind mount） | 只接受 X-Accel-Redirect，外部不能直接存取 |

token 和 ticket 放在路徑裡而不是 query string，是為了讓 artifact 裡的相對路徑（`style.css`、`assets/`）也一樣要通過檢查。

## 7. 主要流程

### 7.1 Agent 建立 artifact

1. `GET /api/artifacts?q=...`：先找有沒有相關的 artifact，避免重複
2. Agent 在本機產生 `<slug>/index.html`（加上 css、js、assets）並檢查
3. `POST /api/artifacts`：送出 metadata，visibility 預設為 private
4. `PUT /api/artifacts/:id/content`：上傳 zip（見 7.3）
5. 回報管理介面上這篇的網址 `kb.example.com/admin/artifacts/<id>`

### 7.2 Agent 更新 artifact

搜尋 → `GET /api/artifacts/:id/content`（下載目前內容的 zip）→ 修改 → 檢查 → `PUT /api/artifacts/:id/content`，產生新版本

### 7.3 上傳與版本

backend 收到 zip → 檢查（擋路徑跳脫 zip slip、限制大小和檔案數量）→ 寫進新的版本目錄 `<artifact_id>/<version>/` → 全部寫完才把 `current_version` 切到新版本 → 舊版本保留，可以還原

**版本只包含內容**：還原舊版本只會回復 HTML、CSS、JS 和 assets，不會回復 title、description 和 tags。這點要寫進 API contract。

### 7.4 Owner 登入

在 `/admin/login` 輸入密碼和 TOTP → `POST /api/auth/login` → 檢查失敗次數限制 → 驗證 bcrypt 和 TOTP → 建立 session → 回傳 cookie（只發給 kb hostname）

### 7.5 打開公開列表頁

訪客打開 kb hostname 的 `/` → frontend 在 server 端呼叫 backend 的 `GET /api/public/artifacts` → 產生 HTML，列表上的連結指向 `content.example.com/a/<slug>/`

### 7.6 打開管理介面

Owner 打開 `/admin/...` → frontend 把 cookie 轉給 backend 的 `GET /api/auth/me` 確認 → 沒登入就導向 `/admin/login`；有登入就回傳頁面 → 頁面上的操作由瀏覽器呼叫 `/api`（帶 `X-KB-Request` header），backend 每次都檢查權限

### 7.7 看 artifact

- **公開**：`content/a/<slug>/` → backend 確認是 public → X-Accel → 反向代理從 bind mount 讀檔
- **分享**：`content/s/<token>/` → backend 用 hash 查 `share_links`（存在、沒撤銷、沒過期）→ X-Accel → 讀檔
- **Owner 預覽**：管理介面呼叫 `POST /api/artifacts/:id/preview` → 拿到 `content/p/<ticket>/` → 用 iframe 或新分頁打開 → backend 驗證 HMAC 和到期時間 → X-Accel → 讀檔
- 檢查不通過一律回 404

### 7.8 修改存取設定

`PUT /api/artifacts/:id/access`，body 是 `{ "mode": "only_me" | "link" | "public" }` → backend 依 4.2 的規則設定 visibility，並建立或撤銷分享連結 → 回傳目前狀態（有有效連結時一併回傳分享網址）

### 7.9 每天備份

排程用 backend image 執行一次性的 `server backup`：

1. **匯出**：把每篇 artifact 的目前版本和 `metadata.json` 匯出成 Portable Artifact Format（見 `portable-artifact-format.md`）
2. **送出**：交給 `BackupTarget`。v1 的實作是 GitRepo：git commit 後 push 到備份 repo（用只對那個 repo 有寫入權限的 deploy key）

### 7.10 部署

1. push 到 main
2. CI 跑測試
3. 建置 frontend 和 backend 兩個 image：各自有獨立的 build cache，CPU 架構依 server 決定
4. 推到 registry，每個 image 都打上 `latest` 和 `sha-<commit>` 兩個 tag
5. 透過 SSH 在 server 執行 `deploy.sh`，**用 `sha-<commit>` 部署**，前後端用同一個 sha
6. `deploy.sh`：拉取兩個 image → 執行 migration（用 backend image 跑一次性的 migrate）→ 更新 frontend 和 backend → health check
7. 失敗就前後端一起換回上一個 sha

## 8. 資料表

| table | 主要欄位 | 說明 |
|---|---|---|
| users | id, password_hash, totp_secret_encrypted, created_at | 只有 Owner 一筆 |
| sessions | id, user_id, expires_at, last_seen_at, created_at | 瀏覽器 session，有效 30 天 |
| api_tokens | id, user_id, name, token_prefix, token_hash, expires_at, last_used_at, revoked_at, created_at | PAT，只存 hash |
| artifacts | id, slug (unique，建立後不能改), title, description, visibility (private / public), current_version, deleted_at, created_at, updated_at | 內容本體放在 storage |
| artifact_versions | id, artifact_id, version, storage_key, created_at | 只記錄內容的版本；每次上傳一筆，可以還原 |
| share_links | id, artifact_id, token_hash (unique), token_encrypted, expires_at, revoked_at, created_at | 每篇最多一條有效 |
| tags | id, name | 統一為小寫 kebab-case |
| artifact_tags | artifact_id, tag_id | |
| activity_logs | id, actor_type (session / token), actor_id, action, target_type, target_id, created_at | 記錄是瀏覽器還是 Agent 做的操作 |

## 9. API（只列用途，實際以平台的 `/api/openapi.json` 為準）

所有會修改資料的請求都必須帶 `X-KB-Request: 1`。

- `POST /api/auth/login`、`POST /api/auth/logout`、`POST /api/auth/logout-all`、`GET /api/auth/me`
- `GET /api/tokens`、`POST /api/tokens`、`DELETE /api/tokens/:id`
- `GET /api/artifacts`（搜尋 title、description、tags：`q`、`tag`）、`POST /api/artifacts`
- `GET /api/artifacts/:id`、`PATCH /api/artifacts/:id`（title、description、tags）、`DELETE /api/artifacts/:id`（soft delete）
- `PUT /api/artifacts/:id/content`（上傳 zip）、`GET /api/artifacts/:id/content`（下載 zip）
- `GET /api/artifacts/:id/versions`、`POST /api/artifacts/:id/versions/:version/restore`（只回復內容）
- `PUT /api/artifacts/:id/access`（`only_me` / `link` / `public`）
- `GET /api/artifacts/:id/share`（顯示目前的分享連結）、`PATCH /api/artifacts/:id/share`（修改或取消到期時間）
- `POST /api/artifacts/:id/preview`（取得 Owner 的短效預覽網址）
- `GET /api/tags`
- `GET /api/public/artifacts`（公開列表，不用登入）
- `GET /api/openapi.json`

## 10. 安全原則

- artifact 放在獨立的 hostname；Owner 的 session 只存在 kb hostname
- 會修改資料的 API 請求要帶自訂 header；API 不對 content hostname 開放 CORS
- Storage 不直接對外，只能由 backend 檢查權限後送出
- 權限只在 backend 判斷。frontend 的登入導向只是為了使用體驗，不是安全邊界
- PAT 只存 hash；分享 token 存 hash 和加密值；TOTP secret 加密存放；credential 不寫進 log
- content hostname 的安全 header 要在反向代理的 internal location 設定，因為 X-Accel-Redirect 轉址時，backend 設的自訂 header 不會被帶過去：
  - `Content-Security-Policy: script-src 'self' 'unsafe-inline'; frame-ancestors https://kb.example.com`（不能載入外部 JS；只允許被管理介面嵌入）
  - `Referrer-Policy: no-referrer`（避免 token 或 ticket 透過 Referer 外洩）
  - `X-Content-Type-Options: nosniff`
  - 不是公開的 artifact 加上 `X-Robots-Tag: noindex`（依 artifact 而不同，由 backend 透過 upstream header 帶入，見第 12 節範例）
- zip 上傳要擋 zip slip，並限制大小和檔案數量；反向代理的上傳大小上限要調大（Nginx 的 `client_max_body_size` 預設只有 1MB）
- container 的 port 只綁在 `127.0.0.1`；資料庫不對外開 port
- 改到登入、權限、分享或 artifact 送出時，要列出可能的繞過路徑並逐一檢查

## 11. 備份

- 備份分兩步：「匯出成 Portable Artifact Format」和「交給 `BackupTarget` 送出」
- `BackupTarget` 是 interface。v1 實作 GitRepo（private GitHub repo），之後可以換成 S3、R2、Backblaze B2 或本機壓縮檔
- 用 backend image 執行一次性的 `server backup`，不另外建 image
- **會匯出**：每篇 artifact 的目前版本、metadata（title、description、tags、visibility、分享連結的加密 token 和到期時間）
- **不匯出**：密碼 hash、TOTP secret、PAT、session。還原後用 CLI 重新設定
- 還原：`server import <dir>`。需要同一把 `APP_ENCRYPTION_KEY`，否則分享連結要重新產生
- GitRepo 的已知限制：刪除的 artifact 還是會留在 git 歷史裡；圖片等二進位檔會讓 repo 越來越大。檔案變多時換其他 `BackupTarget`

## 12. 部署的預設與備案

| 項目 | 預設 | 備案或替代做法（部署前和使用者討論） |
|---|---|---|
| 送出 artifact | 共用 Nginx + bind mount + X-Accel-Redirect | 反向代理不是 Nginx（例如 Caddy、Traefik），或讀不到 bind mount 路徑時，改由 backend 透過 Storage interface 直接送出，安全 header 改由 backend 設定 |
| 前端 | Astro 用 Node 執行 SSR，獨立的 container | 換成 Next.js 或 Nuxt 也是同樣模式 |
| PostgreSQL、Redis | 盤點環境後決定 | 沿用既有的，或用官方 image 新建 |
| image 的 CPU 架構 | 依 server 決定，只 build 需要的架構 | 有需要才建多架構 |
| 連線方式 | container port 綁 `127.0.0.1` | 共用 Nginx 是 container 時，改用共享的 Docker network，並把 bind mount 路徑唯讀掛進 Nginx container |
| 備份目標 | GitRepo | S3、R2、Backblaze B2、本機壓縮檔 |
| CI/CD | GitHub Actions + GHCR | 使用者既有的 CI 與 registry |

- DNS 要有兩筆紀錄（kb 和 content），兩個 hostname 都要有 TLS 憑證
- 平台 repo 要附上反向代理的設定範本
- server 上只放 compose 檔、`.env`、`deploy.sh` 和資料目錄，不放原始碼
- 部署前一律先盤點環境，並和使用者確認；不擅自修改共用的反向代理、資料庫或防火牆

### Nginx 設定範例（共用 Nginx 的預設）

以下只是範例，TLS 設定省略（由 certbot 管理），實際內容以平台 repo 的範本為準。`$upstream_http_*` 在 X-Accel 轉址後的行為，實作時要實測確認。

```nginx
# 管理介面與 API
server {
    listen 443 ssl;
    server_name kb.example.com;
    client_max_body_size 50m;

    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        proxy_pass http://127.0.0.1:4321;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

# artifact 內容
server {
    listen 443 ssl;
    server_name content.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /_artifacts/ {
        internal;
        alias /srv/knowledge/data/artifacts/;
        add_header Content-Security-Policy "script-src 'self' 'unsafe-inline'; frame-ancestors https://kb.example.com" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Robots-Tag $upstream_http_x_robots_tag always;
    }
}
```

## 13. 架構決策記錄

| # | 決策 | 原因 |
|---|---|---|
| 1 | artifact 放在獨立的 hostname | artifact 是 AI 產生的任意 JS，可能被 prompt injection 寫進惡意程式，不能和 Owner 的 session 同源。同源 + CSP 擋不住直接寫在 HTML 裡的 JS；CSP sandbox 會讓 localStorage 和私人 artifact 的子資源請求失效 |
| 2 | visibility 和分享連結分開 | 權限判斷比較簡單；之後要加有密碼的連結或多條連結時，不會被三態欄位卡住 |
| 3 | 分享 token 存 hash 和加密值 | DB 單獨外洩時拿不到可用的 token，同時保留「再要一次給同一條連結」 |
| 4 | 版本只包含內容 | title 和 tags 不需要跟著內容一起回復；簡單，而且寫進 contract |
| 5 | 前端用 Astro SSR | 公開列表頁需要在 server 端產生（SEO 和首次載入速度），管理介面共用同一個前端應用。除非需求改變，不要改成 SPA |
| 6 | X-Accel 是預設，backend 直接送出是備案 | 利用 server 上既有的 Nginx；反向代理不是 Nginx 時要有備案。不另外在平台裡放一層 Nginx |
| 7 | 只有一個 Owner | 不做使用者系統、RESTRICTED、RBAC、第三方登入；資源放在 artifact 的生命週期、Agent 流程、安全邊界、版本、備份和部署 |
| 8 | Owner 用密碼 + TOTP，Agent 用 PAT | 換電腦只需要密碼和手機；Agent 不模擬 Owner 登入 |
| 9 | 備份 = 匯出 + `BackupTarget` | 匯出格式和匯入共用；備份目標可以替換，不寫死 git 指令 |

## 14. 相關 skill

- `knowledge-artifact`：透過平台 API 管理知識內容。它只依賴 API contract，所以修改 API 時要回報會影響它的哪些操作
- `docker-server-deploy`：通用的部署流程（盤點環境、registry、CI/CD、驗收、回滾）。有安裝時，部署交給它

## 15. v1 不包含（未來可能會做）

多使用者、只給指定使用者看（RESTRICTED）、第三方登入、passkey、PAT scope、全文搜尋引擎、Worker、留言和收藏、Workspace 和 Team、Custom Domain、版本差異比對的介面、metadata 的版本紀錄
