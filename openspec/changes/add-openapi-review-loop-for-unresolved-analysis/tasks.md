## 1. Review Artifact

- [x] 1.1 定義 unresolved review artifact 格式與輸出位置。
- [x] 1.2 在 OpenAPI draft 生成階段輸出 unresolved request/response/security 項目。

## 2. Guided Sync Gate

- [x] 2.1 更新 guided-sync 文件與流程，在 upload 前插入 review gate。
- [x] 2.2 讓 review gate 只列出 unresolved / low confidence 項目。

## 3. Apply Decisions

- [x] 3.1 定義 review decision artifact 與回填方式。
- [x] 3.2 在 upload 前套用 review decisions 到 OpenAPI draft。

## 4. Documentation

- [x] 4.1 更新 `skills/laravel-api-docs/SKILL.md`，說明 review loop 何時觸發、如何繼續。

## 5. Verification

- [x] 5.1 驗證 unresolved request/response/security 項目會進 review artifact。
- [x] 5.2 驗證 review decisions 套用後才能繼續 upload。
