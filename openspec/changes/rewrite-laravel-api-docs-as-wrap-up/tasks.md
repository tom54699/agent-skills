## 1. 保留改寫前版本

- [x] 1.1 在目前 commit 建立本機 git tag `laravel-api-docs-guided-sync-final`（是否 push 由使用者決定）

## 2. 移除舊實作

- [x] 2.1 刪除 `skills/laravel-api-docs/src/`、`bin/infer-candidates.php`、`bin/gen-openapi.php`（保留 `bin/render-markdown.php`）
- [x] 2.2 刪除 scripts：`append-sync-history.sh`、`confirm-candidates.sh`、`confirm-openapi-review.sh`、`gen-openapi.sh`、`gen-subset-openapi.sh`、`infer-candidates.sh`、`preflight.sh`、`progress-lib.sh`、`test-upload-changes.sh`
- [x] 2.3 刪除 `tests/laravel_api_docs_commit_driven_test.php`、`tests/laravel_api_docs_contract_surface_test.php`、`tests/laravel_api_docs_query_parameters_test.php`
- [x] 2.4 刪除 `docs/laravel-api-docs-guided-sync.md`
- [x] 2.5 刪除 proposal「Removed Capabilities」列出的 32 個 `openspec/specs/<name>/` 資料夾

## 3. Apidog 腳本

- [x] 3.1 新增 `scripts/apidog-lib.sh`：載入 `.env.agents`（缺值即失敗）、Apidog 請求包裝、YAML→JSON、遞迴收集 `$ref` 修剪 `components`、抓 API tree 並攤平成資料夾與 API 清單
- [x] 3.2 新增 `scripts/export-remote.sh`：可重複的 `--endpoint "METHOD /path"`、`--output FILE`；以 `includeApidogExtensionProperties: true` 匯出，篩出指定 operation 與被引用的 `components`，列出找不到的 endpoint
- [x] 3.3 新增 `scripts/list-folders.sh`：列出資料夾完整路徑與 ID；`--apis` 時列出每支 API（method+path）所在的資料夾
- [x] 3.4 改寫 `scripts/upload-apidog.sh`：`--openapi FILE --targets FILE`；上傳前檢查 spec 可解析、target 欄位完整且 `folder_id` 為整數、target 都存在於 spec，失敗則不送出請求
- [x] 3.5 `upload-apidog.sh` 依 `folder_id` 分批上傳：每批只含該批 operation 與被引用的 `components`，移除 `x-apidog-folder`，沿用 design D7 的 import 選項
- [x] 3.6 `upload-apidog.sh` 上傳後重新抓 API tree，驗證每個 target 存在且位於指定 `folder_id`，不符則列出差異並以非 0 結束；成功時輸出新增、更新數量
- [x] 3.7 確認所有腳本相容 bash 3.2（不用 `mapfile`、associative array、`${var,,}` 等）

## 4. Redoc

- [x] 4.1 精簡 `scripts/gen-html.sh`：參數改為 `--openapi FILE --business-md FILE --output-dir DIR`，`business.md` 為必要輸入；移除 `versions/` 備份與 progress 輸出
- [x] 4.2 `index.html` 文案改為以業務邏輯為主（移除「Sync Summary」等舊 guided-sync 用語），保留連到 `api-docs.html` 的入口

## 5. References 範本

- [x] 5.1 新增 `references/conventions-template.md`：path 格式、共用 headers、security、錯誤回應範本、命名規則、description 寫法、參考 API 等章節與說明，不含任何公司專屬值
- [x] 5.2 新增 `references/business-template.md`：目的、需求、業務邏輯（哪些資料會出現、什麼時候出現或消失）、前端要改什麼

## 6. SKILL.md

- [x] 6.1 改寫 frontmatter `description`：開發完成收尾、產 API 文件、上傳 Apidog、產 Redoc、開 Jira 單等觸發語
- [x] 6.2 改寫本文：流程六步、各步驟的確認點、輸出資料夾結構、首次建立 `conventions.md`、既有 API 以遠端為底、腳本用法、Jira 草稿與建立前確認、不讀寫舊輸出

## 7. 測試

- [x] 7.1 新增 `tests/laravel-api-docs/run-tests.sh`，以假的 `curl` 與 fixture 模擬 Apidog，涵蓋：缺少憑證即失敗；匯出篩選與間接 `$ref` 的 `components` 修剪；找不到 endpoint 的回報；上傳前檢查失敗時不呼叫 `curl`；依資料夾分批且移除 `x-apidog-folder`；驗證通過與資料夾不符兩種結果；`list-folders.sh` 輸出
- [x] 7.2 測試 `gen-html.sh` 以 fixture spec 與 `business.md` 產出 `index.html`、`api-docs.html`，缺少 `business.md` 時失敗
- [x] 7.3 對所有腳本跑 `bash -n`，並以 macOS 內建 `/bin/bash`（3.2）執行 `run-tests.sh`

## 8. Repo 文件與索引

- [x] 8.1 更新 `CLAUDE.md`：專案結構、閱讀順序、以新流程摘要取代「Laravel API 文件 Skill 核心流程摘要」與舊目錄慣例，加上「修改腳本後要跑 `bash tests/laravel-api-docs/run-tests.sh`」
- [x] 8.2 依 8.1 同步更新 `AGENTS.md`
- [x] 8.3 更新 `README.md` 與 `docs/install-skills.md` 的 `laravel-api-docs` 說明，移除 guided-sync 文件連結
- [x] 8.4 修正 `.ai-project-index/config.json`、`skills/ai-project-index/scripts/generate-index.py`、`evaluate-index.py`、`generate-docs.py` 中指向已刪除檔案的路徑與評估案例，改指向新檔案；依 `docs/ai-project-index-usage.md` 重新產生索引

## 9. 驗證

- [x] 9.1 `openspec validate rewrite-laravel-api-docs-as-wrap-up --strict`
- [x] 9.2 在 repo（排除 `openspec/changes/archive/`）搜尋已刪除檔案與 guided-sync 用語的殘留引用
- [x] 9.3 確認 repo 內沒有公司專屬值（自訂 header 名稱、業務錯誤碼、Jira 設定）
- [ ] 9.4 使用者在實際 Laravel 專案跑一次完整流程（建立 `conventions.md` → 撰寫 → 確認 → 上傳與驗證 → Redoc → Jira 草稿），回報問題後修正
