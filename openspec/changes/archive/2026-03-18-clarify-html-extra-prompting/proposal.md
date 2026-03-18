## Why

目前 Step 8/9 對 `extra.md` 的描述偏向實作細節，容易讓使用者直接面對檔名與檔案存在與否，而不是先理解「HTML 頁面要不要加補充內容」。這會讓 guided-sync 對話不自然，也容易漏問。

## What Changes

- 將 Step 8 的提問改成使用者語言，先問是否需要在 HTML 頁面加入補充內容。
- 若使用者要補充內容，改成先由 LLM 與使用者討論內容，再起草 `docs/api-docs/redoc/extra.md`。
- `extra.md` 保留為內部實作檔案，而不是直接暴露給使用者的主提問詞。

## Capabilities

### Modified Capabilities
- `laravel-api-docs-guided-sync`: HTML 生成前的 extra content 提問必須以使用者語言進行，並在需要時先起草 `extra.md`。

## Impact

- 影響 `skills/.curated/laravel-api-docs/SKILL.md`
