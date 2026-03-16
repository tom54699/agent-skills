## 1. 候選確認契約

- [x] 1.1 更新 `skills/laravel-api-docs/SKILL.md`，明確規定候選展示預設只顯示 `status / method / path`。
- [x] 1.2 定義確認迴圈：允許使用者刪除、保留、手動新增 API，直到明確確認。
- [x] 1.3 定義 confirmed JSON 檔案格式與建議路徑。

## 2. OpenAPI 更新鏈路

- [x] 2.1 設計 final-list-driven 的 OpenAPI 更新入口，不得再只依賴全量 route 掃描。
- [x] 2.2 讓後續 OpenAPI 更新腳本以 confirmed JSON 為輸入。
- [x] 2.3 確認 `new / updated / deleted` 在 confirmed JSON -> OpenAPI update 的套用規則。

## 3. 流程整合

- [x] 3.1 串接候選推測、清單確認、OpenAPI 更新、Apidog 同步、HTML 詢問的順序。
- [x] 3.2 保持初始化 / 日常規則照舊，僅補齊 final list 之後的缺口。

## 4. 驗證

- [x] 4.1 驗證使用者可在候選清單中取消與新增 API，且 final list 會正確落檔。
- [x] 4.2 驗證 OpenAPI 更新只影響 confirmed JSON 中的 endpoint。
- [x] 4.3 驗證 Apidog 上傳與 HTML 仍在 final list 套用後才執行。
