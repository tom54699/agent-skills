## Context

前兩筆 change 會提升 request / response 正確性，但仍不可能完全自動化。成熟工具的做法通常是：高頻規則自動處理，複雜規則標 unresolved，再交給人工或覆寫。guided-sync 現在缺的就是這個 review gate。

## Goals / Non-Goals

**Goals**
- 讓 unresolved request/response/security 分析有明確 artifact。
- 讓 guided-sync 在 upload 前可插入 review gate。
- 只 review 低信心與 unresolved 項目，不 review 全量 endpoint。

**Non-Goals**
- 不在這筆 change 直接擴充更多 parser 規則。
- 不在這筆 change 變更 Apidog conflict compare。

## Decisions

### 1. review artifact 以 JSON 輸出

輸出位置：

- `docs/api-docs/reviews/openapi-review.<timestamp>.json`

分類至少包含：

- `unresolved_validation_rules`
- `unresolved_response_shape`
- `unresolved_security`
- `low_confidence_examples`

### 2. guided-sync 在 upload 前加 review gate

流程調整為：

1. infer candidates
2. confirm candidates
3. gen openapi draft
4. review unresolved analysis
5. apply review decisions
6. upload apidog
7. generate html

### 3. LLM 只提示 unresolved 項目

避免把所有 generated schema 都丟給使用者；只針對 unresolved / low confidence 項目討論與確認。

## Risks / Trade-offs

- review loop 會增加一次互動，但能避免錯誤文件直接同步。
- 若 unresolved 太多，需要後續再補 parser coverage。

## Migration Plan

1. 先定義 unresolved review artifact schema。
2. 再在 guided-sync 中插入 review gate。
3. 最後補 apply review decisions 的回填流程。
