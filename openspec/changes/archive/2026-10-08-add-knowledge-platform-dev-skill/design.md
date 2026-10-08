## Context

使用者要建立一個個人 Knowledge Platform：每份知識是一個獨立的 HTML Artifact（自帶 CSS、JS、assets），可以搜尋、分類、分享或公開。平台本身還不存在，會放在另一個 GitHub repo；這個 change 只在本 repo 新增 `knowledge-platform-dev` skill，讓 Agent 以 Platform Engineer 的角色建置與維護平台。

相關但不在這次範圍的 skill：

- `knowledge-artifact`：把討論整理成 artifact，並透過平台 API 管理（之後另開 change）
- `docker-server-deploy`：通用的 Docker 部署流程（之後另開 change）

限制條件：

- 這個 repo 是公開的，skill 會被其他人安裝使用。架構與技術選型必須是**建議預設**，不能寫死成強制規格；建置或部署前要先盤點使用者環境並確認
- 平台只有一個 Owner；其他人只能閱讀公開內容或分享連結
- 內容主要由 AI 產生，必須把 artifact 的 HTML / JS 視為不可信任的程式碼（可能受 prompt injection 影響）
- 使用者過去的部署模式：同一個 repo 建兩個 image（frontend / backend），GitHub Actions 推到 GHCR，用 `sha-<commit>` tag 透過 SSH 部署；server 上已有共用的 Nginx

## Goals / Non-Goals

**Goals:**

- 定義 `knowledge-platform-dev` 的角色與責任邊界
- 把討論收斂的平台 v1 架構寫成可重用的藍圖，並標明哪些是預設、哪些有備案
- 把安全邊界（artifact 獨立 hostname、CSRF header、token 儲存方式）寫成開發平台時必須遵守的規則
- 定義平台對外 API contract 的維護方式，讓之後的 `knowledge-artifact` 只依賴 contract
- 定義平台匯入與備份使用的 Portable Artifact Format

**Non-Goals:**

- 不在這個 repo 實作平台程式碼
- 不新增 `knowledge-artifact` 與 `docker-server-deploy` skill
- 不把這個 skill 加進 `development-workflow` 的流程分派：它是特定用途的 skill，不是開發流程
- 不設計多使用者、RESTRICTED、Workspace、Team 等 v1 以外的功能

## Decisions

### D1：只負責建置平台，不處理知識內容

`knowledge-platform-dev` 可以修改平台 repo 的 frontend、backend、Nginx 設定範本、compose、migration、CI/CD、測試與文件。它不產生或修改知識內容，也不直接寫 DB 或 artifact storage 來產生內容。使用者要求整理或分享知識內容時，明確告知這屬於 `knowledge-artifact` 的範圍。

### D2：架構藍圖是建議預設，平台 repo 是現況依據

`references/architecture-blueprint.md` 收錄 v1 藍圖。使用方式：

- **Bootstrap（平台 repo 尚未建立或是空的）**：先盤點部署環境（既有 Nginx、PostgreSQL、Redis、憑證、CPU 架構），列出要沿用與新建的部分，向使用者提出建置計畫並取得確認後才開始。建置時把確認後的架構寫進平台 repo 的 `docs/architecture.md`
- **Change（平台已存在）**：先讀平台 repo 的 `docs/architecture.md`、API contract 與相關程式碼。藍圖與 repo 不一致時以 repo 為準，並向使用者回報差異，不自行「修正」回藍圖

替代方案：把架構完整寫死在 SKILL.md。不採用，因為平台演進後 skill 會過時，而且其他使用者的環境不同。

### D3：Skill 檔案結構

```
skills/knowledge-platform-dev/
├── SKILL.md                              角色、邊界、模式、開發與安全規則、部署銜接
└── references/
    ├── architecture-blueprint.md         v1 藍圖（hostname、元件、存取與登入模型、路由、流程、資料表、API、備份、部署預設、架構決策記錄）
    └── portable-artifact-format.md       匯入與備份的格式
```

- SKILL.md 依 repo 慣例用英文寫指令，要求輸出使用繁體中文；`description` 加入中文觸發詞
- SKILL.md 保持精簡，細節放 `references/`，需要時才讀
- `metadata.version` 從 `1.0.0` 開始

### D4：Portable Artifact Format

格式：`<slug>/index.html`（必要）、`style.css`、`script.js`、`assets/`（選用），加上 `<slug>/metadata.json`（`format_version`、`generated_by`、slug、title、description、tags、visibility、時間戳記；備份時另含分享連結的加密 token 與到期時間）。

目前只放在 `knowledge-platform-dev`。之後新增 `knowledge-artifact` 時，它要產生同樣格式的本機草稿，會各放一份並用 `format_version` 標記；平台建置後，以平台 repo 的 contract 文件為準。

### D5：只有一個 Owner

不做多使用者、RESTRICTED、註冊。其他人只透過公開或分享連結閱讀。

考慮過的替代方案：

- 用 Google 登入，讓 RESTRICTED 可以指定 email：使用者最後不想做第三方登入
- 用 Git + CI/CD 的靜態網站取代平台：除了做不到「只給指定的人看」，還失去即時撤銷等能力；使用者選擇保留平台

### D6：登入方式

- Owner（瀏覽器）：密碼 + TOTP（Google Authenticator），沒有帳號欄位；session 存 PostgreSQL，有效 30 天；登入失敗次數限制放在記憶體
- Agent：PAT（`kbp_` + 隨機字串，DB 只存 SHA-256 hash）

考慮過的替代方案：用 PAT 貼上登入瀏覽器（換電腦不方便）、只用 TOTP（6 位數的安全性完全依賴失敗次數限制）、passkey（實作最多，而且 Agent 仍需另一套 token）。

### D7：存取模型：visibility 與分享連結分開

資料模型：`visibility`（private / public）和 `share_links`（每篇最多一條有效）是兩個獨立概念。畫面與 API 提供三選一（只有我 / 有連結的人 / 公開），由後端在一個操作內完成組合：「只有我」= 設成 private 並撤銷連結。

考慮過的替代方案：`access_mode` 三態欄位。不採用，因為權限判斷要寫成 switch，未來加有密碼的連結、多條連結時會被卡住。

### D8：分享 token 存 hash 加加密值

`share_links` 存 `token_hash`（查詢用）和 `token_encrypted`（管理介面再次顯示用）。加密金鑰 `APP_ENCRYPTION_KEY` 同時用來加密 TOTP secret，Owner 要另外保存。

考慮過的替代方案：

- 存明文：DB 單獨外洩時，所有分享連結都能直接使用
- 只存 hash、只顯示一次：做不到使用者要求的「再要一次給同一條連結」

### D9：artifact 放在獨立 hostname

```
kb.example.com        公開列表頁、管理介面、API；Owner session 只存在這裡（host-only cookie）
content.example.com   只送 artifact；沒有任何登入狀態
```

- 公開：`content/a/<slug>/`；分享：`content/s/<token>/`；Owner 預覽：`content/p/<ticket>/`（HMAC 簽章、短效、只對一篇有效，不存 DB）
- 所有會修改資料的 API 請求都要帶 `X-KB-Request: 1`，API 不對 content hostname 開放 CORS。兩個子網域屬於同一個 site，cookie 仍可能被帶上，自訂 header 會觸發 preflight 而被擋下

考慮過的替代方案：

- 同源 + CSP `script-src`：擋不住直接寫在 HTML 裡的惡意 JS，它可以用 Owner 的 session 呼叫 API
- CSP `sandbox`：不需要新 hostname，但 artifact 無法使用 localStorage，私人 artifact 的子資源請求也帶不到 cookie
- 在 content hostname 也設登入 cookie：一篇惡意 artifact 就能讀到 Owner 其他的私人 artifact

### D10：送出 artifact：X-Accel 預設，Go 直接送出為備案

預設由 server 上共用的 Nginx 透過 bind mount 和 internal location 讀檔，backend 只回傳 `X-Accel-Redirect`。反向代理不是 Nginx（Caddy、Traefik），或讀不到 bind mount 路徑時，改由 backend 透過 Storage interface 直接送出。

X-Accel 轉址時，backend 設的自訂 header 不會被帶過去，所以 content hostname 的安全 header 要在 Nginx internal location 設定。

考慮過的替代方案：平台自帶一個 Nginx container 處理 X-Accel。使用者不想要第二層反向代理。

### D11：前端用 Astro SSR，獨立 container

frontend container 用 Node 執行 Astro SSR（與使用者既有 Next.js 專案的模式相同），共用 Nginx 依路徑轉給 frontend 或 backend。理由：公開列表頁需要在 server 端產生（SEO 與首次載入速度），管理介面共用同一個前端應用。除非需求改變，不要改成 SPA。

考慮過的替代方案：Go 一起送出靜態檔（使用者希望前後端分開）、靜態 build 由共用 Nginx 送出、frontend container 放 `nginx:alpine`。

### D12：版本只包含內容，上傳採原子切換

每次上傳寫進新的版本目錄 `<artifact_id>/<version>/`，全部寫完才切換 `current_version`；舊版本保留可還原。還原只回復內容，不回復 title、description、tags，並寫進 API contract。

### D13：備份 = 匯出 + BackupTarget

`server backup` 先匯出成 Portable Artifact Format，再交給 BackupTarget 送出。v1 實作 GitRepo（private GitHub repo），之後可換成 S3、R2、Backblaze B2 或本機壓縮檔。不匯出密碼 hash、TOTP secret、PAT、session。

考慮過的替代方案：直接把 `pg_dump` 放進 git（含敏感資料、不可讀）、寫死 git 指令（之後無法換目標）。

### D14：部署交給 `docker-server-deploy`

藍圖保留部署預設：同一個 repo 建 frontend / backend 兩個 image，各自 build cache，打 `latest` 與 `sha-<commit>` tag，用同一個 sha 部署與回滾；migration、備份、匯入都用 backend image 執行。實際流程交給 `docker-server-deploy` skill；未安裝時依藍圖預設並先與使用者確認。

### D15：平台對外 API contract 以 OpenAPI 提供

平台在 `/api/openapi.json` 提供 OpenAPI contract。修改 API 時必須同步更新 contract、評估向下相容，並回報會影響哪些 Agent 端的操作。這樣之後的 `knowledge-artifact` 只需要依賴 contract，不需要知道平台內部實作。

## Risks / Trade-offs

- [藍圖與平台實作漂移] → 平台建置後以平台 repo 的 `docs/architecture.md` 為準；藍圖只用在 bootstrap 與缺少文件時
- [Agent 把藍圖當強制規格，跳過確認直接建置] → SKILL.md 明確要求先盤點環境、提出計畫、取得確認
- [AI 產生的 artifact 含惡意 JS] → 獨立 hostname、host-only session cookie、CSRF 自訂 header、短效預覽 ticket
- [之後新增 `knowledge-artifact` 時 Portable Artifact Format 出現兩份副本] → 用 `format_version` 標記；修改格式時兩份一起更新
- [GitRepo 備份長期膨脹] → BackupTarget 可替換；藍圖註明限制
- [skill 公開在 public repo，平台安全設計也公開] → 安全不依賴隱匿；skill 內不放任何 secret、使用者網域或 server 資訊

## Migration Plan

只新增 skill 與文件，沒有遷移。若要撤回，刪除 skill 目錄並還原文件清單即可。

## Open Questions

- 平台 repo 的名稱、實際網域（kb / content hostname）：使用者建置平台時決定，不寫進 skill
- `knowledge-artifact` 與 `docker-server-deploy` 的內容：各自另開 change 討論
