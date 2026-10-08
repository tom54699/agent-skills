# Portable Artifact Format

平台匯入（`server import`）與備份匯出（`server backup`）共用的 artifact 格式。AI Agent 在平台無法連線時存下的本機草稿，也使用同一種格式。

目前版本：`format_version: 1`

## 目錄結構

```
<slug>/
├── index.html        必要
├── style.css         選用
├── script.js         選用
├── assets/           選用（圖片、SVG、字型、JS library 等）
└── metadata.json     必要
```

- `<slug>` 是英文 kebab-case，和 `metadata.json` 裡的 `slug` 相同
- artifact 內的引用一律用相對路徑，不依賴平台的任何路由或其他 artifact 的檔案
- 不從外部 CDN 載入 JS；需要的 library 放進 `assets/`

## metadata.json

```json
{
  "format_version": 1,
  "generated_by": "knowledge-platform-dev v1.0.0",
  "slug": "mysql-composite-index",
  "title": "MySQL Composite Index",
  "description": "複合索引的欄位順序、最左前綴原則與 EXPLAIN 判讀",
  "tags": ["mysql", "index", "performance"],
  "visibility": "private",
  "created_at": "2026-10-08T10:00:00Z",
  "updated_at": "2026-10-08T10:00:00Z",
  "share": {
    "token_encrypted": "<base64>",
    "expires_at": null
  }
}
```

| 欄位 | 必要 | 說明 |
|---|---|---|
| `format_version` | 是 | 格式版本，目前是 `1` |
| `generated_by` | 是 | 產生者與版本，例如 `knowledge-platform-dev v1.0.0`、`knowledge-artifact v1.0.0` |
| `slug` | 是 | 英文 kebab-case，建立後不能改 |
| `title` | 是 | 標題 |
| `description` | 是 | 一兩句摘要 |
| `tags` | 是 | 小寫 kebab-case 的陣列，可以是空陣列 |
| `visibility` | 是 | `private` 或 `public`；本機草稿一律 `private` |
| `created_at`、`updated_at` | 是 | ISO 8601（UTC） |
| `share` | 否 | 只出現在備份匯出，而且該篇有有效的分享連結時才有。`token_encrypted` 是用 `APP_ENCRYPTION_KEY` 加密後的值 |

## 匯出規則（備份）

- 每篇只匯出目前版本的內容，舊版本不匯出
- 不匯出密碼 hash、TOTP secret、PAT、session
- soft delete 的 artifact 不匯出

## 匯入規則

- 逐篇檢查 `format_version`；不認得的版本跳過並列入報告
- `slug` 已經存在時，預設不覆蓋，列入報告；使用者明確指定時，才把內容匯入成該篇的新版本
- 有 `share` 時，用目前的 `APP_ENCRYPTION_KEY` 解密：
  - 解密成功：還原分享連結（同時寫入 `token_hash` 和 `token_encrypted`）
  - 解密失敗（金鑰不同）：不還原，列入報告，由 Owner 之後重新產生
- 匯入的內容一樣要經過上傳時的檢查（路徑跳脫、大小、檔案數量）
- 匯入結束後回報：成功、跳過、失敗各有哪些 slug

## 修改這個格式時

- 調高 `format_version`，並說明舊版本的相容方式
- 這份文件在 `knowledge-platform-dev` 和 `knowledge-artifact` 各有一份，內容必須完全相同，修改時兩份一起更新
