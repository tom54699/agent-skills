## 1. Method-Level Impact Extraction

- [x] 1.1 在 `infer-candidates.sh` 新增 Service 檔案 diff 的 method 萃取邏輯（以 `git diff --unified=0` 為基礎）。
- [x] 1.2 建立 `changed service methods -> controller actions` 的映射資料結構。
- [x] 1.3 將既有「service 檔案變更即全標 updated」邏輯改為 method 命中才標記。

## 2. Action-Bound Dependency Mapping

- [x] 2.1 擴充 `parse-controller.sh`，輸出 action 內 service method 呼叫清單。
- [x] 2.2 將 Request/Resource 判定改為 action-scope（僅 action 實際引用才算 impacted）。
- [x] 2.3 將 Exception 判定改為 action-scope（只在相關 catch/throw flow 命中時標記）。

## 3. Candidate Signals and Documentation

- [x] 3.1 在候選輸出 `signals` 增加 method/action 級命中欄位（如 `service_method_hit`、`dependency_action_hit`）。
- [x] 3.2 更新 `change_reason` 組裝規則，讓使用者可讀出具體命中來源。
- [x] 3.3 更新 `skills/laravel-api-docs/SKILL.md` 的 Step 2 說明與 debug 欄位定義。

## 4. Verification and Regression

- [x] 4.1 建立最小回歸案例：同一 service 多 action，僅一個 method 變更時只命中對應 endpoint。
- [x] 4.2 驗證 Request-only、Resource-only、Exception-only 變更都只影響 action-bound endpoint。
- [x] 4.3 驗證初始化與日常模式的候選數量、準確率與執行時間，確保無明顯回退。
