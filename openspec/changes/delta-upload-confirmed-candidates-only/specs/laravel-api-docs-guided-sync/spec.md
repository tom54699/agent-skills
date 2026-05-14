## MODIFIED Requirements

### Requirement: Step 7 uploads only confirmed candidate endpoints to Apidog
`guided-sync` Step 7 的 Apidog 上傳 SHALL 以 delta 模式執行：提供 confirmed candidate file 時，`upload-apidog.sh` 自動過濾 payload，只上傳本次 confirmed 的 `new` 與 `updated` endpoint；`--no-delta` 可回退全量行為。

SKILL.md 的 `upload-apidog.sh` 呼叫範例 SHALL 更新為：
```bash
bash "$SKILL_DIR/upload-apidog.sh" \
  --openapi docs/api-docs/openapi.yaml \
  --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json
```

（delta 為預設行為，不需額外 flag；全量上傳需明確加 `--no-delta`）

#### Scenario: Guided sync Step 7 sends delta payload
- **WHEN** Step 7 執行 `upload-apidog.sh` 並提供 `--candidate-file`
- **THEN** Apidog 只收到本次 confirmed candidates 對應的 endpoint，其他既有 API 不被觸動

#### Scenario: Full rebuild uses --no-delta
- **WHEN** 使用者要求「完整重建」
- **THEN** Step 7 以 `--no-delta` 呼叫 `upload-apidog.sh`，上傳完整 spec
