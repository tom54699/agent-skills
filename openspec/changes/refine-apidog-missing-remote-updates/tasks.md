## 1. Conflict Semantics

- [x] 1.1 調整 `skills/laravel-api-docs/scripts/upload-apidog.sh`，讓 `missing_remote_endpoint` 輸出 `blocking=false`，且不再被當作 hard conflict。
- [x] 1.2 調整 `apply_keep_remote_strategy()`，只對 `blocking=true` 且 remote 已存在的衝突保留遠端版本。

## 2. Verification And Docs

- [x] 2.1 以代表性初始化情境驗證 `updated + remote missing` 仍會進 upload payload。
- [x] 2.2 更新 `skills/laravel-api-docs/SKILL.md`，說明 Step 7 中 `missing_remote_endpoint` 的行為。
