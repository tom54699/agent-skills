## MODIFIED Requirements

### Requirement: Step 7 performs path strategy alignment check before uploading
`guided-sync` Step 7 SHALL 在上傳至 Apidog 前自動執行 path strategy alignment check：`upload-apidog.sh` 比對本地與遠端 path strategy，不一致時阻擋並提示使用者確認。

SKILL.md Step 7 SHALL 補充：
- Alignment check 為自動執行，不需使用者額外操作
- 若 check 阻擋，使用者可選擇：調整 `path_strategy` 後重新執行，或確認無誤後加 `--skip-alignment-check` 繼續
- `--skip-alignment-check` 適用於 CI 或已知環境，不建議常態使用

#### Scenario: Step 7 alignment check blocks on mismatch
- **WHEN** Step 7 偵測到 local 與 remote path strategy 不一致
- **THEN** 上傳中止，LLM 向使用者說明差異並提供下一步選項

#### Scenario: Step 7 alignment check passes silently
- **WHEN** Step 7 偵測到 local 與 remote path strategy 一致，或遠端為空
- **THEN** 上傳繼續，不輸出額外訊息
