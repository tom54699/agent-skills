## 1. Post-Upload Verification

- [x] 1.1 擴充 `skills/laravel-api-docs/scripts/upload-apidog.sh`，在 import 後重新 export remote OpenAPI。
- [x] 1.2 實作 candidate-driven 驗證：confirmed `new`/`updated` endpoint 必須出現在 remote `paths`。
- [x] 1.3 驗證失敗時不得寫 success history，且需回傳非 0 exit 與清楚錯誤。

## 2. Documentation And Verification

- [x] 2.1 更新 `skills/laravel-api-docs/SKILL.md`，說明 Step 7 的成功條件包含 post-upload verification。
- [x] 2.2 以本地 fixture 驗證：import counters 成功但 remote export 缺 endpoint 時，腳本必須失敗。
