## Context

`upload-apidog.sh` 目前的上傳流程：
1. 讀取完整 `openapi.yaml`，轉為 JSON
2. 直接作為 import payload 送給 Apidog

Candidate file 只用於 conflict detection，不影響上傳內容。導致每次 sync 都是「全量覆蓋」，無法精確控制本次只更新哪些 endpoint。

## Goals / Non-Goals

**Goals:**
- 有 `--candidate-file` 時，自動過濾 payload 只含 confirmed candidates 的 paths（new + updated）
- `info`、`servers`、`components`、`tags` 等共用節點保持完整，不被過濾掉
- 新增 `--no-delta` flag 可強制全量上傳（向後相容）
- `openapi.yaml` 保持不變（仍為 canonical full record）

**Non-Goals:**
- 不修改 `gen-openapi.sh` 或 PHP generator
- 不改變 conflict detection 邏輯
- 不影響沒有 candidate file 的上傳路徑（行為維持全量）

## Decisions

### D1：Delta spec 在記憶體內組裝，不落地為獨立檔案

替代方案：把 delta spec 寫到 `docs/api-docs/delta/<timestamp>.json` 再上傳。

**選擇記憶體組裝**：delta spec 只是 upload payload，沒有獨立存在的價值；落地會多一個需要清理的暫存檔，且 full spec 才是要保存的 canonical record。

### D2：過濾邏輯以 `method + path` 為 key，從 candidate file 取交集

```
confirmed candidates (new + updated)
    │  { method, path } set
    ▼
full spec .paths
    │  filter: 保留 key 出現在 candidate set 的 paths
    ▼
delta spec .paths  (N 個 endpoint)
    +
info / servers / components / tags (完整保留)
    ▼
上傳 payload
```

### D3：`--no-delta` flag 跳過過濾，回退全量行為

用於：
- 使用者明確要求完整重建
- candidate file 格式異常時的安全 fallback
- 向後相容舊的呼叫方式

## Risks / Trade-offs

- **漏傳 shared components**：若 delta endpoint 引用的 `$ref` 指向 `components/schemas`，但 components 已完整保留，不會有問題。`components` 保留原則不應變動。
- **path strategy 不一致導致 key 對不上**：candidate file 的 path 應與 local spec 的 path key 一致（都由 gen-openapi.sh 產出），正常情況下不會有 mismatch。若有，delta 過濾後 payload 為空，上傳會 no-op，不會造成錯誤。

## Migration Plan

- 不涉及資料遷移
- `--no-delta` 可讓既有呼叫方式不受影響
- SKILL.md 說明更新即可，不需要 breaking change 通知
