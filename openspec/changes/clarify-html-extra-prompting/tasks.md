## 1. Prompt Clarification

- [x] 1.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，將 Step 8 改成使用者語言，不直接以 `extra.md` 為主提問。
- [x] 1.2 補充規則：若使用者要補充內容，先由 LLM 與使用者討論內容，再起草 `docs/api-docs/redoc/extra.md`。

## 2. Flow Guardrail

- [x] 2.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，明確禁止在未起草 `extra.md` 的情況下直接執行 `--with-extra`。

## 3. Verification

- [x] 3.1 驗證文件規則已明確區分「使用者語言的 extra content」與內部實作檔案 `extra.md`。
