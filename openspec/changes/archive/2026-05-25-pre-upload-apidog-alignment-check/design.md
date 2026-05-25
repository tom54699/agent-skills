## Context

`upload-apidog.sh` 已有 `export_remote_openapi_json` 函式（在 conflict detection 時呼叫）。Remote OpenAPI export 含有完整 paths，足以推斷遠端實際的 path strategy，不需要額外 API 呼叫。

現有 `detect_path_strategy_from_openapi` 函式可對任意 spec 做偵測（已用於 local spec），直接套用到 remote spec 即可。

## Goals / Non-Goals

**Goals:**
- 比對 local `path_strategy`（來自 candidate file 或 flag）與 remote spec 偵測結果
- 不一致時輸出明確錯誤訊息並中止上傳
- Tags 新增（新資料夾）靜默通過，不視為錯誤
- `--skip-alignment-check` 可跳過（CI / 已知環境）

**Non-Goals:**
- 不比對資料夾（tag）結構差異（新增 tag 是正常行為）
- 不自動修正 path strategy（由使用者決定）
- 不對 remote spec 為空（全新專案）的情況報 mismatch

## Decisions

### D1：Alignment check 在 remote export 後、conflict detection 前執行

執行順序：
```
validate_input
    ↓
fetch_remote_openapi   ← 已有，timing 記錄中
    ↓
check_alignment        ← 新增（用 remote spec 做 path strategy 比對）
    ↓
detect_conflicts       ← 現有
    ↓
build_request / upload
```

這樣 remote export 只做一次，alignment check 和 conflict detection 共用同一份 remote spec。

### D2：Remote spec paths 為空時跳過 alignment check

全新 Apidog 專案（路徑為空）無法推斷 strategy，不應阻擋上傳。偵測到 remote paths 為空時，alignment check 靜默通過。

### D3：Mismatch 輸出結構化訊息，交由 LLM 或使用者決定

```
[Alignment Warning]
本地 path_strategy: strip-api-prefix-to-server  （路徑：/users, /orders）
Apidog 偵測 strategy: keep-full-path             （路徑：/api/users, /api/orders）

Path strategy 不一致，可能導致 endpoint 重複或錯位。
請確認後以 --skip-alignment-check 繼續，或調整 path_strategy。
```

不自動修正，讓使用者/LLM 判斷後決定。

## Risks / Trade-offs

- **Remote spec 偵測不準**：`detect_path_strategy_from_openapi` 已有 fallback 邏輯（paths 不夠多時可能回傳空字串）。回傳空字串時視為「無法判斷」，跳過比對，不阻擋上傳。
- **`--skip-alignment-check` 被濫用**：flag 存在讓 CI 可以繞過，但 flag 語意清楚，屬有意識的選擇。
