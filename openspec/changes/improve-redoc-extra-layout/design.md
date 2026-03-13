## Context

目前 HTML 是單頁直接 prepend `extra.md`，資訊架構很差。使用者已確認不要同頁雙區塊，而是固定改成多頁：

- `index.html` 負責摘要與導覽
- `api-docs.html` 保持純 Redoc
- 表格必須正確顯示

## Goals / Non-Goals

**Goals**
- 固定輸出首頁摘要頁與獨立 API 文件頁。
- 補充內容有像真正首頁的視覺層次。
- 支援 Markdown 表格，讓錯誤碼清單可讀。

**Non-Goals**
- 不引入前端框架。

## Decisions

### 1. 固定多頁輸出

HTML 結構改成：

- `index.html`：首頁，放 `extra.md` 與導覽
- `api-docs.html`：純 Redoc

### 2. Markdown 補表格支援

`render-markdown.php` 至少補：

- pipe table
- `thead` / `tbody`

避免錯誤碼表變成一堆段落。

### 3. 樣式重做成文件站風格

方向：

- 明確首頁 hero / nav / content
- 表格可讀性提升
- 不再把 extra content 視為頁首貼文

## Migration Plan

1. 先改 Markdown renderer。
2. 再改 `gen-html.sh` 固定輸出首頁與 Redoc 兩頁。
3. 最後更新 `SKILL.md` 說明新呈現方式。
