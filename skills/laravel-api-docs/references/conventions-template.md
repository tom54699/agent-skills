# API 慣例檔範本

Laravel 專案的 `docs/api-docs/conventions.md` 依這份章節建立。這個檔案只給 AI 讀，用 markdown 自由描述即可。

- 本範本的值都是佔位，不代表任何專案；公司專屬的值只寫在 Laravel 專案裡，不寫回 skill repo。
- 首次建立時：請使用者指定一支寫得好的既有 API，用 `export-remote.sh` 匯出，從中抽出下面各章節的內容，給使用者確認後存檔。
- 之後發現慣例有變，直接更新 Laravel 專案裡的 `conventions.md`。

---

```markdown
# API 慣例

## 參考 API
- 格式範本：`METHOD /path`（寫新 API 前先匯出這支對照）

## Path 格式
- Apidog 上的 path 是否含 `/api` 前綴：<是／否>，例如 `<path 範例>`
- path 參數寫法：例如 `{order_id}`

## 共用 request headers
| Header | 必填 | 說明 | 範例 |
|---|---|---|---|
| `<header>` | <是／否> | <說明> | `<值>` |

## 認證
- security scheme：<名稱與類型，例如 bearer>
- 哪些 middleware 代表需要認證：<例如 auth:api>

## 成功回應格式
- 外層結構：<例如 code、message、data>
- 成功時的 code：<值>

## 錯誤回應
只列 action 實際會發生的錯誤：有驗證才有 422、需要認證才有 401。

| HTTP status | 業務 code | 何時出現 | message 範例 |
|---|---|---|---|
| 401 | `<code>` | 未登入或 token 失效 | <訊息> |
| 422 | `<code>` | 驗證失敗 | <訊息> |
| 500 | `<code>` | 業務例外 | <訊息> |

範例 body：
（貼一份實際的錯誤回應 JSON）

## 命名
- request／response key：<例如 snake_case>
- 日期時間格式：<例如 Y-m-d H:i:s>
- 列舉值寫法：<例如在 description 列出每個值的意義>

## description 寫法
- operation description 只寫一句；詳細的業務說明放到 Redoc 首頁（business.md）

## 資料夾
- 模組與 Apidog 資料夾的對應習慣：<例如 Driver 相關放 Driver/...>
```
