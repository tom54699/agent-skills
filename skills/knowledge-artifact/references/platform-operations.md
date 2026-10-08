# 平台操作

這份對照依據 Knowledge Platform v1 藍圖。**平台提供 `GET /api/openapi.json` 時，以它為準**；欄位名稱、路徑或回應格式不同時，照 OpenAPI 調整。

## 設定

| 環境變數 | 用途 |
|---|---|
| `KB_BASE_URL` | 平台的管理 / API hostname，例如 `https://kb.example.com` |
| `KB_API_TOKEN` | 在平台管理介面產生的 PAT（`kbp_` 開頭） |

確認設定時只檢查有沒有值，不要印出內容：

```bash
[ -n "$KB_BASE_URL" ] && [ -n "$KB_API_TOKEN" ] && echo "configured" || echo "missing"
```

## 共同規則

- 每個請求都帶 `Authorization: Bearer $KB_API_TOKEN` 和 `X-KB-Request: 1`（會修改資料的請求一定要帶，讀取的請求一起帶也無妨）
- token 只透過環境變數引用。不要 `echo` token、不要用 `curl -v`（會印出 header）、不要寫進任何檔案
- 回報給使用者的網址，一律用 API 回傳的網址欄位，不要自己組出 content hostname 的網址
- 以下範例用 `-w '\nHTTP %{http_code}\n'` 顯示狀態碼

## 操作對照

| 操作 | Method 與路徑 | 說明 |
|---|---|---|
| 搜尋 | `GET /api/artifacts?q=<字詞>&tag=<tag>` | v1 搜尋 title、description、tags |
| 取得單篇 | `GET /api/artifacts/:id` | |
| 建立 | `POST /api/artifacts` | 送 metadata，預設只有自己看得到 |
| 修改 metadata | `PATCH /api/artifacts/:id` | title、description、tags |
| 上傳內容 | `PUT /api/artifacts/:id/content` | zip，產生新版本 |
| 下載內容 | `GET /api/artifacts/:id/content` | zip，目前版本 |
| 版本列表 | `GET /api/artifacts/:id/versions` | |
| 還原版本 | `POST /api/artifacts/:id/versions/:version/restore` | 只回復內容，不回復 metadata |
| 存取設定 | `PUT /api/artifacts/:id/access` | `{"mode": "only_me" \| "link" \| "public"}` |
| 查看分享連結 | `GET /api/artifacts/:id/share` | |
| 修改到期時間 | `PATCH /api/artifacts/:id/share` | `{"expires_at": "<ISO 8601>" \| null}` |
| 刪除 | `DELETE /api/artifacts/:id` | soft delete；只依明確指令 |
| 現有 tags | `GET /api/tags` | 建立 metadata 前先查，能沿用就沿用 |

### 用 slug 找特定 artifact

v1 的搜尋不涵蓋 slug。用 slug 裡的關鍵字搜尋，再從結果中找 `slug` 欄位**完全相同**的那一篇。如果 OpenAPI 提供 slug 篩選或查詢，就改用它。

## curl 範例

### 搜尋

```bash
curl -sS -G "$KB_BASE_URL/api/artifacts" \
  --data-urlencode "q=composite index" \
  -H "Authorization: Bearer $KB_API_TOKEN" -H "X-KB-Request: 1" \
  -w '\nHTTP %{http_code}\n'
```

### 建立

```bash
curl -sS -X POST "$KB_BASE_URL/api/artifacts" \
  -H "Authorization: Bearer $KB_API_TOKEN" -H "X-KB-Request: 1" \
  -H "Content-Type: application/json" \
  -d '{"slug":"mysql-composite-index","title":"MySQL 複合索引","description":"欄位順序、最左前綴原則與 EXPLAIN 判讀","tags":["mysql","index"]}' \
  -w '\nHTTP %{http_code}\n'
```

### 上傳內容

zip 的根目錄就是 artifact 目錄的內容（`index.html` 在最上層），不要包含 `metadata.json` 和系統檔。

```bash
tmp="$(mktemp -d)"
(cd ~/knowledge-artifacts/mysql-composite-index && zip -qr "$tmp/artifact.zip" . -x metadata.json -x '*.DS_Store')
curl -sS -X PUT "$KB_BASE_URL/api/artifacts/<id>/content" \
  -H "Authorization: Bearer $KB_API_TOKEN" -H "X-KB-Request: 1" \
  -H "Content-Type: application/zip" \
  --data-binary @"$tmp/artifact.zip" \
  -w '\nHTTP %{http_code}\n'
```

### 下載目前內容（更新前）

本機目錄已經存在時，先改名保留，再解壓縮平台上的版本。

```bash
dir=~/knowledge-artifacts/mysql-composite-index
tmp="$(mktemp -d)"
curl -sS -f "$KB_BASE_URL/api/artifacts/<id>/content" \
  -H "Authorization: Bearer $KB_API_TOKEN" -H "X-KB-Request: 1" \
  -o "$tmp/artifact.zip"
[ -d "$dir" ] && mv "$dir" "$dir.local-$(date +%Y%m%d%H%M%S)"
mkdir -p "$dir" && unzip -q "$tmp/artifact.zip" -d "$dir"
```

下載後，用 `GET /api/artifacts/:id` 的 metadata 重新寫入 `metadata.json`。

### 存取設定

```bash
curl -sS -X PUT "$KB_BASE_URL/api/artifacts/<id>/access" \
  -H "Authorization: Bearer $KB_API_TOKEN" -H "X-KB-Request: 1" \
  -H "Content-Type: application/json" \
  -d '{"mode":"link"}' \
  -w '\nHTTP %{http_code}\n'
```

## 錯誤處理

| 狀況 | 處理方式 |
|---|---|
| 連線失敗、逾時、5xx | 視為平台不可用：artifact 留在本機，回報「尚未上傳」，不要一直重試 |
| 401 | token 無效或過期：請使用者到平台管理介面重新產生 PAT 並更新 `KB_API_TOKEN` |
| 403 | 先確認有帶 `X-KB-Request: 1`；仍然失敗就回報給使用者 |
| 404 | id 錯誤或已刪除：重新搜尋 |
| 409 | slug 已存在：問使用者要更新那一篇，還是換一個 slug |
| 413 | 檔案太大：檢查 `assets/`，壓縮圖片或移除用不到的檔案 |
| 400、422 | 內容驗證失敗（例如 zip 路徑不合法、檔案數量超過上限）：依錯誤訊息修正後再上傳 |
