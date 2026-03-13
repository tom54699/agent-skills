## Why

目前 `gen-html.sh` 會把 `extra.md` 直接塞在 Redoc 同頁最上方，導致：

- 補充內容和 API 文件缺乏清楚區隔
- 使用者看起來像單頁貼文，不像文件站
- Markdown 表格無法正確渲染，資訊可讀性很差

## What Changes

- 將 HTML 輸出固定改成多頁：
  - `index.html`：摘要首頁
  - `api-docs.html`：純 Redoc API 文件頁
- 補 `render-markdown.php` 的表格支援。
- 讓 `extra.md` 渲染到首頁，而不是和 Redoc 混在同一頁。

## Capabilities

### Modified Capabilities
- `laravel-api-docs-guided-sync`: HTML output should use a dedicated summary home page and a separate API reference page.

## Impact

- 影響 `skills/laravel-api-docs/scripts/gen-html.sh`
- 影響 `skills/laravel-api-docs/bin/render-markdown.php`
- 影響 `skills/laravel-api-docs/SKILL.md`
