## 1. upload-apidog.sh：Alignment Check 實作

- [x] 1.1 新增 `--skip-alignment-check` flag 解析（預設 false）
- [x] 1.2 實作 `check_path_strategy_alignment`：以 `detect_path_strategy_from_openapi` 偵測 remote spec，與 `PATH_STRATEGY` 比對；remote paths 為空或偵測結果為空時靜默跳過
- [x] 1.3 Mismatch 時輸出結構化說明（本地 vs 遠端策略、路徑範例）並 fail
- [x] 1.4 在 `fetch_remote_openapi` 之後、`detect_conflicts` 之前插入 `check_path_strategy_alignment` 呼叫

## 2. SKILL.md：Step 7 說明更新

- [x] 2.1 補充 alignment check 的自動執行說明與 mismatch 處理流程
- [x] 2.2 補充 `--skip-alignment-check` 使用時機與注意事項
