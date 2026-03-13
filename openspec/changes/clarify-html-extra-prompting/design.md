## Context

`gen-html.sh` 需要 `extra.md` 才能帶入額外內容，這是合理的實作分層；但 guided-sync 對使用者的互動不應直接把 `extra.md` 當成主概念。應先談「HTML 補充內容」，再由 LLM 轉成 `extra.md`。

## Goals / Non-Goals

**Goals**
- 將 Step 8 改成使用者可理解的互動文案。
- 明確規定：使用者要補充內容時，先起草 `extra.md` 再進 Step 9。
- 保持 `gen-html.sh` 仍只負責吃 `extra.md`，不在腳本內新增對話邏輯。

**Non-Goals**
- 不修改 `gen-html.sh` 核心產生邏輯。
- 不在這筆 change 產生固定模板內容。

## Decisions

### 1. Step 8 使用者語言優先

對使用者應先問：

- 要不要產 HTML 文件？
- 要不要在 HTML 頁面加補充說明？

不應直接先問「要不要套用 extra.md」。

### 2. extra.md 是內部產物

若使用者要補充內容：

1. LLM 與使用者討論要放哪些內容
2. LLM 起草 `docs/api-docs/redoc/extra.md`
3. 再執行 `gen-html.sh --with-extra`

### 3. 若使用者要求補充內容但未起草 extra.md，不得直接進 Step 9

避免再次出現直接以檔案存在與否來回覆使用者，而沒有先說明 extra content 的用途。

## Migration Plan

1. 更新 `SKILL.md` Step 8/9 的對話規則。
2. 明確寫出 extra content -> `extra.md` 的內部轉換。
