## 1. upload-apidog.sh：Delta 過濾實作

- [x] 1.1 新增 `--no-delta` flag 解析（預設 false）
- [x] 1.2 實作 `build_delta_spec`：從 candidate file 取 `new`+`updated` 的 `{method, path}` set，從 local spec JSON 過濾對應 path keys，保留 `info`/`servers`/`components`/`tags`
- [x] 1.3 實作空 delta 中止邏輯：過濾後 paths 為空時輸出警告並 exit（不送空 payload）
- [x] 1.4 在現有的 `build_request` 步驟前插入 delta 過濾：有 `--candidate-file` 且未 `--no-delta` 時，以 delta spec 取代 `UPLOAD_SPEC_JSON_FILE`

## 2. SKILL.md：Step 7 說明更新

- [x] 2.1 更新 Step 7 的 `upload-apidog.sh` 呼叫範例，說明 delta 為預設行為
- [x] 2.2 補充「完整重建」情境使用 `--no-delta` 的說明
