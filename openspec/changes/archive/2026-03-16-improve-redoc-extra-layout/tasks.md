## 1. Markdown Rendering

- [x] 1.1 擴充 `skills/laravel-api-docs/bin/render-markdown.php`，支援 Markdown 表格。

## 2. HTML Layout

- [x] 2.1 重做 `skills/laravel-api-docs/scripts/gen-html.sh` 的輸出結構，固定產出 `index.html` 與 `api-docs.html`。
- [x] 2.2 首頁補導覽與多頁樣式，避免 extra content 直接貼在 Redoc 頁首。

## 3. Documentation

- [x] 3.1 更新 `skills/laravel-api-docs/SKILL.md`，說明 HTML 補充內容會以首頁摘要頁呈現。

## 4. Verification

- [x] 4.1 驗證帶 `extra.md` 的 HTML 會產出 `index.html` 與 `api-docs.html` 兩頁。
- [x] 4.2 驗證 Markdown 表格在首頁 HTML 中可正確顯示。
